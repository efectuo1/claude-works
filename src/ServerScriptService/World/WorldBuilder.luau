--!strict
--[[
	Construye el mundo mínimo cuando el lugar de Studio no lo trae: relieve de terreno,
	luz de atardecer, la zona "Campos de Brasa" con sus puntos de spawn, decoración y plantillas de mobs.
	Solo crea lo que falte, y no toca un terreno que ya exista (CountCells > 0).
	Es provisional: cuando haya mapa real, este script se puede retirar.
]]

local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local Result = require(ReplicatedStorage.Shared.Util.Result)
local HubBuilder = require(script.Parent.HubBuilder)
local MapLayout = require(script.Parent.MapLayout)
local ModeArenaBuilder = require(script.Parent.ModeArenaBuilder)

local WorldBuilder = {}

local MAP_HALF = MapLayout.HALF_SIZE
local VOXEL = 4 -- Roblox exige resolución 4 para WriteVoxels
local MIN_Y = -28 -- por debajo del fondo del mar (-22)
local MAX_Y = 12 -- por encima de la meseta (~3)
local SPAWN_XZ = MapLayout.spawnPoints()
local height = MapLayout.height

-- Altura real de la superficie del terreno. El terreno se escribe en voxels de 4 studs, así que la
-- altura calculada puede quedar unos studs por debajo: decoración y spawns se colocan con un raycast.
local function surface(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), params)
	if hit ~= nil then
		return hit.Position.Y
	end
	return height(x, z)
end

local SURFACE: { [string]: Enum.Material } = {
	Rock = Enum.Material.Rock,
	Sand = Enum.Material.Sand,
	Grass = Enum.Material.Grass,
	Stone = Enum.Material.Cobblestone,
}

local function materialAt(x: number, z: number, h: number): Enum.Material
	return SURFACE[MapLayout.surfaceAt(x, z, h)]
end

local function buildTerrain()
	local terrain = workspace.Terrain
	if terrain:CountCells() > 0 then
		return -- ya hay terreno (por ejemplo, uno hecho a mano en Studio): no se sobrescribe
	end

	local cells = (2 * MAP_HALF) // VOXEL
	local layers = (MAX_Y - MIN_Y) // VOXEL

	-- Altura y material por columna, una sola vez (es la parte cara).
	local heights: { { number } } = {}
	local columnMaterial: { { Enum.Material } } = {}
	for ix = 1, cells do
		heights[ix] = {}
		columnMaterial[ix] = {}
		local x = -MAP_HALF + (ix - 0.5) * VOXEL
		for iz = 1, cells do
			local z = -MAP_HALF + (iz - 0.5) * VOXEL
			local h = height(x, z)
			heights[ix][iz] = h
			if h > MapLayout.SEA_FLOOR + 0.5 then
				columnMaterial[ix][iz] = materialAt(x, z, h)
			else
				columnMaterial[ix][iz] = Enum.Material.Rock
			end
		end
	end

	local materials: { { { Enum.Material } } } = {}
	local occupancy: { { { number } } } = {}
	for ix = 1, cells do
		materials[ix] = {}
		occupancy[ix] = {}
		local x = -MAP_HALF + (ix - 0.5) * VOXEL
		for iy = 1, layers do
			materials[ix][iy] = {}
			occupancy[ix][iy] = {}
			local y = MIN_Y + (iy - 0.5) * VOXEL
			for iz = 1, cells do
				local z = -MAP_HALF + (iz - 0.5) * VOXEL
				local h = heights[ix][iz]
				local occ = math.clamp((h - y) / VOXEL + 0.5, 0, 1)
				local material = Enum.Material.Air
				if occ > 0 then
					material = columnMaterial[ix][iz]
				elseif y < MapLayout.SEA_LEVEL then
					-- Sobre el fondo del mar y bajo el nivel del agua: agua de verdad, no un vacío.
					material = Enum.Material.Water
					occ = 1
				end
				occupancy[ix][iy][iz] = occ
				materials[ix][iy][iz] = material
			end
		end
	end

	local region = Region3.new(Vector3.new(-MAP_HALF, MIN_Y, -MAP_HALF), Vector3.new(MAP_HALF, MAX_Y, MAP_HALF))
	terrain:WriteVoxels(region, VOXEL, materials, occupancy)
	terrain.WaterColor = Color3.fromRGB(60, 215, 240)
	terrain.WaterTransparency = 0.5
	terrain.WaterWaveSize = 0.15
end

local function ensure(parent: Instance, className: string, configure: (Instance) -> ())
	if parent:FindFirstChildOfClass(className :: any) == nil then
		local created = Instance.new(className :: any)
		configure(created)
		created.Parent = parent
	end
end

local function buildLighting()
	-- Sin niebla ni neblina: el color tiene que verse tal cual. (Antes la atmósfera tiñía todo de naranja.)
	ensure(Lighting, "Atmosphere", function(atmosphere)
		local a = atmosphere :: Atmosphere
		-- Neblina ligera de azul claro: el fondo se ve lejano y el cielo parece más vivo.
		a.Density = 0.12
		a.Haze = 0.6
		a.Glare = 0.15
		a.Color = Color3.fromRGB(205, 235, 255)
		a.Decay = Color3.fromRGB(170, 215, 255)
	end)
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(120, 110, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(180, 170, 200)
	-- Fog fuera de alcance: no se ve nada a menos que se acerque mucho.
	Lighting.FogStart = 5000
	Lighting.FogEnd = 100000
	Lighting.FogColor = Color3.fromRGB(255, 255, 255)
	-- Post-proceso: brillo de las brasas, color más intenso y rayos de sol.
	ensure(Lighting, "BloomEffect", function(bloom)
		local b = bloom :: BloomEffect
		b.Intensity = 0.35 -- menos brillo: la arena y el camino no deslumbran
		b.Size = 28
		b.Threshold = 0.9
	end)
	ensure(Lighting, "ColorCorrectionEffect", function(cc)
		local c = cc :: ColorCorrectionEffect
		c.Saturation = 1.2
		c.Contrast = 0.08
		c.TintColor = Color3.fromRGB(255, 255, 255)
	end)
	ensure(Lighting, "SunRaysEffect", function(rays)
		local r = rays :: SunRaysEffect
		r.Intensity = 0.15
		r.Spread = 0.7
	end)
end

-- Colores del terreno: se fijan por material antes de escribir voxels.
local function paintTerrain(terrain: Terrain)
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(104, 190, 88))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(250, 220, 150))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(150, 140, 178))
	terrain:SetMaterialColor(Enum.Material.Cobblestone, Color3.fromRGB(175, 165, 150))
end

local function buildSpawnLocation()
	if workspace:FindFirstChildOfClass("SpawnLocation") ~= nil then
		return
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Inicio"
	-- Pad pequeño en la plaza, delante de la fuente: el punto de aparición de los jugadores.
	spawn.Size = Vector3.new(6, 1, 6)
	local start = MapLayout.HUB_SPAWN
	spawn.Position = Vector3.new(start.X, surface(start.X, start.Y) + 0.5, start.Y)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(255, 200, 80)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = workspace
end

-- ---------- Decoración, caminos y puentes ----------
-- Semillas fijas: siempre el mismo mapa. Todo se coloca con raycast sobre la superficie real del terreno.

local function newPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	if shape ~= nil then
		p.Shape = shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Disco plano (cilindro con el eje vertical).
local function disc(parent: Instance, name: string, radius: number, thickness: number, position: Vector3, color: Color3, material: Enum.Material, collide: boolean): Part
	local p = newPart(parent, name, Vector3.new(thickness, radius * 2, radius * 2), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
	p.CanCollide = collide
	return p
end

local function signText(board: Part, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = gui
end

local WOOD_BROWN = Color3.fromRGB(120, 80, 50)
local CANOPY = { Color3.fromRGB(70, 160, 80), Color3.fromRGB(45, 135, 75), Color3.fromRGB(115, 195, 95) }
local PINE_GREENS = { Color3.fromRGB(40, 130, 80), Color3.fromRGB(55, 150, 85), Color3.fromRGB(30, 110, 70) }
local STONE_GREY = { Color3.fromRGB(150, 150, 160), Color3.fromRGB(130, 130, 145), Color3.fromRGB(170, 165, 160) }
local FLOWER_COLORS = {
	Color3.fromRGB(255, 80, 160),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(80, 230, 255),
	Color3.fromRGB(180, 110, 255),
}

-- Árbol de copa redonda: tronco marrón y tres bolas de verde.
local function roundTree(parent: Instance, p: Vector2, rng: Random, index: number)
	local base = surface(p.X, p.Y)
	local trunkHeight = rng:NextNumber(8, 11)
	newPart(parent, `Arbol_{index}`, Vector3.new(1.8, trunkHeight, 1.8), CFrame.new(p.X, base + trunkHeight / 2, p.Y), WOOD_BROWN, Enum.Material.Wood)
	local crown = rng:NextNumber(8, 11)
	for k = 1, 3 do
		local size = crown * rng:NextNumber(0.7, 1)
		local ball = newPart(parent, "Copa", Vector3.new(size, size, size), CFrame.new(p.X + rng:NextNumber(-1.6, 1.6), base + trunkHeight + rng:NextNumber(0, 1.5), p.Y + rng:NextNumber(-1.6, 1.6)), CANOPY[(index + k) % #CANOPY + 1], Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		ball.CanCollide = false
	end
end

-- Pino de pisos: tronco corto y cuatro discos de verde cada vez más estrechos, como los pinos de la referencia.
local function pine(parent: Instance, p: Vector2, rng: Random, index: number)
	local base = surface(p.X, p.Y)
	local trunkHeight = rng:NextNumber(4, 6)
	newPart(parent, `Pino_{index}`, Vector3.new(1.6, trunkHeight, 1.6), CFrame.new(p.X, base + trunkHeight / 2, p.Y), WOOD_BROWN, Enum.Material.Wood)
	local scale = rng:NextNumber(0.9, 1.3)
	for k = 1, 4 do
		local radius = (6 - k * 1.1) * scale
		disc(parent, "PinoPiso", radius, 2.2, Vector3.new(p.X, base + trunkHeight * 0.7 + (k - 1) * 2 * scale + 1.1, p.Y), PINE_GREENS[(index + k) % #PINE_GREENS + 1], Enum.Material.Grass, false)
	end
end

-- Claro de arena con un anillo de piedras y dos rocas encima, como los círculos de arena de la referencia.
local function clearing(parent: Instance, center: Vector2, radius: number, rng: Random)
	local y = surface(center.X, center.Y)
	disc(parent, "ClaroArena", radius, 0.5, Vector3.new(center.X, y + 0.1, center.Y), Color3.fromRGB(240, 215, 160), Enum.Material.Sand, false)
	local stones = math.floor(radius * 0.7)
	for i = 1, stones do
		local a = i * 2 * math.pi / stones + rng:NextNumber(-0.1, 0.1)
		local sx = center.X + math.cos(a) * radius * 0.82
		local sz = center.Y + math.sin(a) * radius * 0.82
		local size = rng:NextNumber(1.2, 2.4)
		newPart(parent, "PiedraClaro", Vector3.new(size, size * 0.6, size * 1.1), CFrame.new(sx, surface(sx, sz) + size * 0.25, sz) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), STONE_GREY[i % #STONE_GREY + 1], Enum.Material.Slate)
	end
	for _ = 1, 2 do
		local sx = center.X + rng:NextNumber(-radius, radius) * 0.4
		local sz = center.Y + rng:NextNumber(-radius, radius) * 0.4
		local size = rng:NextNumber(3, 4.5)
		newPart(parent, "RocaClaro", Vector3.new(size, size * 0.8, size), CFrame.new(sx, surface(sx, sz) + size * 0.3, sz) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color3.fromRGB(125, 125, 145), Enum.Material.Slate)
	end
end

-- Decoración: árboles, pinos, claros de arena y estanques de brasa.
local function buildDecor()
	if workspace:FindFirstChild("Decor") ~= nil then
		return
	end
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = workspace
	local rng = Random.new(7)

	-- Solo se colocan fuera de zonas, puentes y caminos: así nunca bloquean la ruta de los mobs.
	local function randomPoint(margin: number): Vector2
		while true do
			local p = Vector2.new(rng:NextNumber(-MAP_HALF, MAP_HALF), rng:NextNumber(-MAP_HALF, MAP_HALF))
			if MapLayout.isClear(p, margin) then
				return p
			end
		end
	end
	-- Cerca del hub hay menos vegetación: el bosque se espesa hacia el borde de la isla.
	local function forestPoint(margin: number): Vector2
		while true do
			local p = randomPoint(margin)
			if p.Magnitude > 190 or rng:NextNumber() < 0.3 then
				return p
			end
		end
	end

	for i = 1, 240 do
		roundTree(decor, forestPoint(6), rng, i)
	end
	for i = 1, 260 do
		pine(decor, forestPoint(6), rng, i)
	end

	-- Claros de arena: doce repartidos por la isla grande y uno en el centro de cada satélite.
	local placed = 0
	while placed < 12 do
		local p = randomPoint(26)
		if p.Magnitude > 150 and p.Magnitude < 290 then
			placed += 1
			clearing(decor, p, rng:NextNumber(16, 24), rng)
		end
	end
	for _, island in MapLayout.islands() do
		if island.id ~= "principal" then
			clearing(decor, island.center, 16, rng)
		end
	end

	-- Estanques de brasa, lejos de la plaza.
	for i = 1, 8 do
		local p = randomPoint(10)
		while p.Magnitude < 200 do
			p = randomPoint(10)
		end
		local pool = disc(decor, `Brasa_{i}`, 3.5, 0.3, Vector3.new(p.X, surface(p.X, p.Y) + 0.2, p.Y), Color3.fromRGB(255, 110, 40), Enum.Material.Neon, false)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 120, 50)
		light.Range = 16
		light.Brightness = 1.6
		light.Parent = pool
	end
end

-- Flores de neón: color y vida sin coste de física (no colisionan).
local function buildFlowers()
	if workspace:FindFirstChild("Flores") ~= nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Flores"
	local rng = Random.new(21)
	local count = 0
	for _ = 1, 600 do
		local center = Vector2.new(rng:NextNumber(-MAP_HALF, MAP_HALF), rng:NextNumber(-MAP_HALF, MAP_HALF))
		if MapLayout.isClear(center, 8) and (center.Magnitude > 140 or rng:NextNumber() < 0.15) then
			for _ = 1, rng:NextInteger(5, 9) do
				local a = rng:NextNumber(0, math.pi * 2)
				local p = center + Vector2.new(math.cos(a), math.sin(a)) * rng:NextNumber(0, 4.5)
				count += 1
				local size = rng:NextNumber(0.8, 1.3)
				local flower = newPart(folder, `Flor_{count}`, Vector3.new(size, size, size), CFrame.new(p.X, surface(p.X, p.Y) + 0.6, p.Y), FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)], Enum.Material.Neon, Enum.PartType.Ball)
				flower.CanCollide = false
				flower.CanQuery = false
				flower.CanTouch = false
			end
		end
	end
	folder.Parent = workspace
end

-- Rocas grandes sobre el borde de cada meseta, justo antes de las terrazas.
local function buildBoulders()
	if workspace:FindFirstChild("Rocas") ~= nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Rocas"
	local rng = Random.new(55)
	local count = 0
	for _, island in MapLayout.islands() do
		local inner = island.radius - island.rim
		local amount = if island.id == "principal" then 90 else 10
		for _ = 1, amount do
			local angle = rng:NextNumber(0, math.pi * 2)
			local p = island.center + Vector2.new(math.cos(angle), math.sin(angle)) * rng:NextNumber(inner - 14, inner - 3)
			local size = rng:NextNumber(4, 9)
			if MapLayout.isClear(p, 3) then
				count += 1
				newPart(folder, `Roca_{count}`, Vector3.new(size, size * rng:NextNumber(0.6, 0.9), size * rng:NextNumber(0.8, 1.1)), CFrame.new(p.X, surface(p.X, p.Y) + size * 0.3, p.Y) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), Color3.fromRGB(140, 128, 165), Enum.Material.Slate)
			end
		end
	end
	folder.Parent = workspace
end

-- Caminos de adoquín: de la plaza a cada puente y de cada puente al centro de su isla, con farolas.
local ROAD_COLOR = Color3.fromRGB(190, 178, 160)
local function buildRoads()
	if workspace:FindFirstChild("Caminos") ~= nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Caminos"
	local lampCount = 0
	for _, road in MapLayout.roads() do
		local along = road.to - road.from
		local length = along.Magnitude
		local dir = along.Unit
		local side = Vector2.new(-dir.Y, dir.X)
		local step = 9
		for offset = 0, length - 1, step do
			local a = road.from + dir * offset
			local segment = math.min(step, length - offset)
			local mid = a + dir * (segment / 2)
			local y = surface(mid.X, mid.Y) + 0.25
			newPart(folder, "Camino", Vector3.new(road.halfWidth * 2, 0.5, segment + 0.6), CFrame.lookAt(Vector3.new(mid.X, y, mid.Y), Vector3.new(mid.X + dir.X, y, mid.Y + dir.Y)), ROAD_COLOR, Enum.Material.Cobblestone)
			-- Una farola cada cuatro tramos, alternando lado.
			if (offset // step) % 4 == 2 then
				lampCount += 1
				local sign = if lampCount % 2 == 0 then 1 else -1
				local lampPos = mid + side * (road.halfWidth + 1.6) * sign
				local ground = surface(lampPos.X, lampPos.Y)
				newPart(folder, "FarolaPoste", Vector3.new(0.7, 7, 0.7), CFrame.new(lampPos.X, ground + 3.5, lampPos.Y), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
				local bulb = newPart(folder, "FarolaLuz", Vector3.new(1.8, 1.8, 1.8), CFrame.new(lampPos.X, ground + 7.4, lampPos.Y), Color3.fromRGB(255, 235, 150), Enum.Material.Neon, Enum.PartType.Ball)
				bulb.CanCollide = false
			end
		end
	end
	folder.Parent = workspace
end

-- Puente de madera sobre el mar, de la isla grande a un satélite: tablero, tablones, barandillas y pilares.
-- Al principio lleva un arco con el nombre del destino, de cara a quien llega desde la plaza.
local BRIDGE_DECK = Color3.fromRGB(205, 150, 90)
local BRIDGE_DARK = Color3.fromRGB(140, 95, 55)

local function buildBridge(bridge: MapLayout.Bridge)
	if workspace:FindFirstChild(`Puente_{bridge.id}`) ~= nil then
		return
	end
	local model = Instance.new("Model")
	model.Name = `Puente_{bridge.id}`
	local a = Vector3.new(bridge.from.X, surface(bridge.from.X, bridge.from.Y) + 0.3, bridge.from.Y)
	local b = Vector3.new(bridge.to.X, surface(bridge.to.X, bridge.to.Y) + 0.3, bridge.to.Y)
	local length = (b - a).Magnitude
	local width = bridge.halfWidth * 2
	-- Eje del puente: -Z local apunta hacia el satélite, así que el tablero mide `length` en Z.
	local base = CFrame.lookAt((a + b) / 2, b)

	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3): Part
		return newPart(model, name, size, base * offset, color, Enum.Material.Wood)
	end

	piece("Tablero", Vector3.new(width, 0.8, length), CFrame.new(0, -0.4, 0), BRIDGE_DECK)
	local z = -length / 2 + 1.5
	while z < length / 2 do
		piece("Tablon", Vector3.new(width + 0.4, 0.2, 1.1), CFrame.new(0, 0.05, z), BRIDGE_DARK)
		z += 3
	end
	for _, side in { -1, 1 } do
		piece("Barandilla", Vector3.new(0.5, 0.5, length), CFrame.new(side * (width / 2 - 0.25), 2.4, 0), BRIDGE_DARK)
		z = -length / 2 + 2
		while z < length / 2 do
			piece("Poste", Vector3.new(0.6, 2.6, 0.6), CFrame.new(side * (width / 2 - 0.25), 1.0, z), BRIDGE_DARK)
			z += 6
		end
	end
	-- Pilares hasta el fondo, cada 15 studs.
	z = -length / 2 + 8
	while z < length / 2 - 4 do
		for _, side in { -1, 1 } do
			local top = (base * CFrame.new(side * (width / 2 - 0.8), -0.8, z)).Position
			local depth = top.Y - (MapLayout.SEA_FLOOR + 1)
			newPart(model, "Pilar", Vector3.new(1.2, depth, 1.2), CFrame.new(top - Vector3.new(0, depth / 2, 0)), BRIDGE_DARK, Enum.Material.Wood)
		end
		z += 15
	end

	-- Arco de entrada en el extremo de la isla grande (z local = +length/2).
	local arch = base * CFrame.new(0, 0, length / 2 - 2)
	for _, side in { -1, 1 } do
		newPart(model, "ArcoPoste", Vector3.new(1.4, 11, 1.4), arch * CFrame.new(side * (bridge.halfWidth + 2.5), 5.2, 0), BRIDGE_DARK, Enum.Material.Wood)
	end
	newPart(model, "ArcoTravesano", Vector3.new(bridge.halfWidth * 2 + 7, 1.6, 1.8), arch * CFrame.new(0, 10.6, 0), BRIDGE_DARK, Enum.Material.Wood)
	-- El cartel mira hacia +Z local, es decir, hacia la plaza.
	local board = newPart(model, "ArcoCartel", Vector3.new(11, 3, 0.4), arch * CFrame.new(0, 8, 0.9) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(50, 40, 60), Enum.Material.SmoothPlastic)
	signText(board, bridge.name)
	model.Parent = workspace
end

local function buildZone()
	local zones = workspace:FindFirstChild("Zones") or Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = workspace

	local zone = zones:FindFirstChild("starter_ember_fields") or Instance.new("Folder")
	zone.Name = "starter_ember_fields"
	zone.Parent = zones

	local spawns = zone:FindFirstChild("Spawns") or Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = zone

	-- Se regeneran en cada arranque: así los puntos siempre coinciden con SPAWN_XZ.
	spawns:ClearAllChildren()
	for name, xz in SPAWN_XZ do
		do
			local point = Instance.new("Part")
			point.Name = name
			point.Size = Vector3.new(2, 1, 2)
			point.Position = Vector3.new(xz.X, surface(xz.X, xz.Y) + 3, xz.Y)
			point.Anchored = true
			point.CanCollide = false
			point.Transparency = 1
			point.Parent = spawns
		end
	end

	if workspace:FindFirstChild("Mobs") == nil then
		local mobs = Instance.new("Folder")
		mobs.Name = "Mobs"
		mobs.Parent = workspace
	end
end

-- Zombi provisional (sin modelo definitivo): cuerpo, cabeza, brazos y piernas unidos a HumanoidRootPart.
-- Medidas pensadas para un Humanoid tipo R6: el origen está en el tronco y los pies quedan 3 studs por debajo.
-- Así coincide con el spawn de MobSpawner (punto + 3 studs).
local ZOMBIE_SKIN = Color3.fromRGB(120, 200, 90)
local ZOMBIE_CLOTHES = Color3.fromRGB(125, 85, 55)
local ZOMBIE_DARK = Color3.fromRGB(30, 20, 20)

-- Escala por mob: el mismo zombi, más grande para el bruto y más pequeño para el espíritu.
local MOB_SCALE: { [string]: number } = {
	ember_wolf = 1,
	ember_sprite = 0.8,
	ash_brute = 1.6,
}

local function makeZombie(def: Types.MobDef): Model
	local scale = MOB_SCALE[def.id] or 1
	local model = Instance.new("Model")
	model.Name = def.id

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1) * scale
	root.Transparency = 1
	root.CanCollide = false
	root.Parent = model
	model.PrimaryPart = root

	local function piece(name: string, size: Vector3, offset: Vector3, color: Color3)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size * scale
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Massless = true
		-- Solo el torso colisiona: brazos, piernas y cabeza se enganchaban en rocas y árboles.
		part.CanCollide = name == "Torso"
		part.CFrame = root.CFrame * CFrame.new(offset * scale)
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end

	piece("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0), ZOMBIE_CLOTHES)
	piece("Cabeza", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0), ZOMBIE_SKIN)
	piece("BrazoIzq", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), ZOMBIE_SKIN)
	piece("BrazoDer", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), ZOMBIE_SKIN)
	piece("PiernaIzq", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), ZOMBIE_CLOTHES)
	piece("PiernaDer", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), ZOMBIE_CLOTHES)
	-- Cara: dos ojos oscuros y una boca, en la parte delantera (-Z).
	piece("OjoIzq", Vector3.new(0.25, 0.25, 0.1), Vector3.new(-0.3, 1.7, -0.62), ZOMBIE_DARK)
	piece("OjoDer", Vector3.new(0.25, 0.25, 0.1), Vector3.new(0.3, 1.7, -0.62), ZOMBIE_DARK)
	piece("Boca", Vector3.new(0.6, 0.15, 0.1), Vector3.new(0, 1.35, -0.62), ZOMBIE_DARK)

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	-- Contorno que se ve a través de la niebla y de las paredes: el mob siempre se distingue.
	local highlight = Instance.new("Highlight")
	highlight.FillColor = ZOMBIE_SKIN
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 36)
	gui.StudsOffset = Vector3.new(0, 2.6 * scale + 0.8, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90 -- sin esto, las etiquetas de todos los mobs se encimaban a cualquier distancia
	gui.Adornee = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = def.displayName
	label.TextColor3 = Color3.fromRGB(255, 230, 200)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Parent = gui
	gui.Parent = root

	return model
end

-- Plantillas siempre regeneradas: un cambio de modelo se ve en el siguiente arranque.
local function buildTemplates(mobDefs: { [string]: Types.MobDef })
	local templates = ServerStorage:FindFirstChild("MobTemplates") or Instance.new("Folder")
	templates.Name = "MobTemplates"
	templates.Parent = ServerStorage
	templates:ClearAllChildren()
	for id, def in mobDefs do
		makeZombie(def).Parent = templates
	end
end

-- Cada paso se aísla: si uno falla (por ejemplo, el terreno), los demás se construyen igual.
local function step(name: string, fn: () -> ()): boolean
	local ok, err = pcall(fn)
	if not ok then
		warn(`[World] el paso "{name}" falló: {err}`)
	end
	return ok
end

-- Punto de entrada. Idempotente: se puede llamar en cada arranque.
function WorldBuilder.build(mobDefs: { [string]: Types.MobDef }): Result.Result<boolean>
	local allOk = true
	allOk = step("terreno", buildTerrain) and allOk
	-- Los colores se repintan en cada arranque, también si el terreno ya existía (por ejemplo, de una partida guardada).
	allOk = step("colores del terreno", function()
		paintTerrain(workspace.Terrain)
	end) and allOk
	allOk = step("luz", buildLighting) and allOk
	allOk = step("punto de inicio", buildSpawnLocation) and allOk
	allOk = step("decoración", buildDecor) and allOk
	allOk = step("flores", buildFlowers) and allOk
	allOk = step("rocas", buildBoulders) and allOk
	allOk = step("caminos", buildRoads) and allOk
	allOk = step("puentes", function()
		for _, bridge in MapLayout.bridges() do
			buildBridge(bridge)
		end
	end) and allOk
	allOk = step("zona", buildZone) and allOk
	allOk = step("hub", function()
		HubBuilder.build(height)
	end) and allOk
	allOk = step("modalidades", function()
		ModeArenaBuilder.build()
	end) and allOk
	allOk = step("plantillas de mobs", function()
		buildTemplates(mobDefs)
	end) and allOk
	if not allOk then
		return Result.err("el mundo se construyó a medias; mira los avisos [World] de arriba")
	end
	return Result.ok(true)
end

return WorldBuilder

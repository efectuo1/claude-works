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
local VOXEL = 4 -- resolución del terreno en studs (múltiplo de 4 para alinear la región)
local MIN_Y = -24
local MAX_Y = 48
local SPAWN_XZ = MapLayout.spawnPoints()
local height = MapLayout.height

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

	-- Altura por columna, una sola vez (es la parte cara).
	local heights: { { number } } = {}
	for ix = 1, cells do
		heights[ix] = {}
		local x = -MAP_HALF + (ix - 0.5) * VOXEL
		for iz = 1, cells do
			heights[ix][iz] = height(x, -MAP_HALF + (iz - 0.5) * VOXEL)
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
				occupancy[ix][iy][iz] = occ
				materials[ix][iy][iz] = if occ > 0 then materialAt(x, z, h) else Enum.Material.Air
			end
		end
	end

	local region = Region3.new(Vector3.new(-MAP_HALF, MIN_Y, -MAP_HALF), Vector3.new(MAP_HALF, MAX_Y, MAP_HALF))
	terrain:WriteVoxels(region, VOXEL, materials, occupancy)
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
		c.Saturation = 0.95
		c.Contrast = 0.12
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
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(110, 220, 90))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(250, 220, 150))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(150, 150, 170))
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
	spawn.Position = Vector3.new(start.X, height(start.X, start.Y) + 0.5, start.Y)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(255, 200, 80)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = workspace
end

-- Decoración: rocas, árboles muertos y estanques de brasa. Semillas fijas: siempre el mismo mapa.
local function buildDecor()
	if workspace:FindFirstChild("Decor") ~= nil then
		return
	end
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = workspace
	local rng = Random.new(7)

	-- Solo se colocan fuera de zonas y caminos: así nunca bloquean la ruta de los mobs.
	local function randomPoint(margin: number): Vector2
		while true do
			local p = Vector2.new(rng:NextNumber(-MAP_HALF, MAP_HALF), rng:NextNumber(-MAP_HALF, MAP_HALF))
			if MapLayout.isClear(p, margin) then
				return p
			end
		end
	end

	-- Árboles de copa redonda: tronco marrón y tres bolas de verde que no bloquean a los mobs.
	local CANOPY = { Color3.fromRGB(70, 160, 80), Color3.fromRGB(45, 135, 75), Color3.fromRGB(115, 195, 95) }
	for i = 1, 90 do
		local p = randomPoint(6)
		local base = height(p.X, p.Y)
		local trunkHeight = rng:NextNumber(5, 7)
		local trunk = Instance.new("Part")
		trunk.Name = `Arbol_{i}`
		trunk.Anchored = true
		trunk.Material = Enum.Material.Wood
		trunk.Color = Color3.fromRGB(120, 80, 50)
		trunk.Size = Vector3.new(1.2, trunkHeight, 1.2)
		trunk.CFrame = CFrame.new(p.X, base + trunkHeight / 2, p.Y)
		trunk.Parent = decor
		local crown = rng:NextNumber(4.5, 6)
		for k = 1, 3 do
			local ball = Instance.new("Part")
			ball.Name = "Copa"
			ball.Shape = Enum.PartType.Ball
			ball.Anchored = true
			ball.CanCollide = false
			ball.Material = Enum.Material.SmoothPlastic
			ball.Color = CANOPY[(i + k) % #CANOPY + 1]
			local size = crown * rng:NextNumber(0.7, 1)
			ball.Size = Vector3.new(size, size, size)
			local dx = rng:NextNumber(-1.6, 1.6)
			local dz = rng:NextNumber(-1.6, 1.6)
			ball.CFrame = CFrame.new(p.X + dx, base + trunkHeight + rng:NextNumber(0, 1.5), p.Y + dz)
			ball.Parent = decor
		end
	end

	for i = 1, 16 do
		local p = randomPoint(10)
		local pool = Instance.new("Part")
		pool.Name = `Brasa_{i}`
		pool.Shape = Enum.PartType.Cylinder
		pool.Anchored = true
		pool.CanCollide = false
		pool.Material = Enum.Material.Neon
		pool.Color = Color3.fromRGB(255, 110, 40)
		pool.Size = Vector3.new(0.3, 7, 7)
		pool.CFrame = CFrame.new(p.X, height(p.X, p.Y) + 0.2, p.Y) * CFrame.Angles(0, 0, math.rad(90))
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 120, 50)
		light.Range = 16
		light.Brightness = 1.6
		light.Parent = pool
		pool.Parent = decor
	end
end

-- Flores de neón: color y vida sin coste de física (no colisionan).
local FLOWER_COLORS = {
	Color3.fromRGB(255, 80, 160),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(80, 230, 255),
	Color3.fromRGB(180, 110, 255),
	Color3.fromRGB(255, 120, 40),
}

local function buildFlowers()
	if workspace:FindFirstChild("Flores") ~= nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Flores"
	local rng = Random.new(21)
	for i = 1, 600 do
		local p = Vector2.new(rng:NextNumber(-MAP_HALF, MAP_HALF), rng:NextNumber(-MAP_HALF, MAP_HALF))
		if MapLayout.isClear(p, 1) then
			local flower = Instance.new("Part")
			flower.Name = `Flor_{i}`
			flower.Shape = Enum.PartType.Ball
			flower.Size = Vector3.new(0.9, 0.9, 0.9)
			flower.Material = Enum.Material.Neon
			flower.Color = FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)]
			flower.Anchored = true
			flower.CanCollide = false
			flower.CanQuery = false
			flower.CanTouch = false
			flower.Position = Vector3.new(p.X, height(p.X, p.Y) + 0.5, p.Y)
			flower.Parent = folder
		end
	end
	folder.Parent = workspace
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
			point.Position = Vector3.new(xz.X, height(xz.X, xz.Y) + 3, xz.Y)
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

--!strict
--[[
	Hub de entrada. Disposición (vista desde la fuente, con el norte arriba = -Z):
	  Centro: plaza con fuente azul de cinco pisos. El jugador aparece al lado, por el este.
	  En cada punta de la isla central hay un punto de interés enorme sobre un círculo de arena:
	    Norte: gran ruleta.   Sur: tableros de clasificación.
	    Oeste: tres casas de modalidad (Oleadas, Jefes, próximamente).   Este: casa de la tienda.
	Las posiciones y escalas salen de MapLayout.landmarks(). Se rehace en cada arranque.
	Los carteles, el prompt de la tienda y los pads de entrada son los que usan los servicios.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local ModeLayout = require(ServerScriptService.World.ModeLayout)
local PadBuilder = require(ServerScriptService.World.PadBuilder)
local MapLayout = require(ServerScriptService.World.MapLayout)

local HubBuilder = {}

local HOUSE_SCALE = 1.6
local PAD_OFFSET = 9.5 -- distancia del pad a la casa, hacia la plaza

-- Casas de modalidad, de norte a sur. Cada una tiene un pad delante que lleva a su lobby.
local MODE_HOUSES = {
	{ id = "Oleadas", z = -12, color = Color3.fromRGB(90, 230, 110), destination = "wave" },
	{ id = "Jefes", z = 0, color = Color3.fromRGB(255, 90, 90), destination = "boss" },
	{ id = "Proximamente", z = 12, color = Color3.fromRGB(150, 150, 165), destination = nil },
}

local SAND = Color3.fromRGB(250, 220, 150)
local STONE_COLORS = {
	Color3.fromRGB(200, 200, 215),
	Color3.fromRGB(255, 190, 120),
	Color3.fromRGB(170, 220, 255),
}
local FOUNTAIN_BLUE = Color3.fromRGB(60, 130, 235)
local FOUNTAIN_BLUE_DARK = Color3.fromRGB(35, 90, 200)
local WATER_COLOR = Color3.fromRGB(120, 220, 255)
local WOOD = Color3.fromRGB(240, 210, 160) -- madera clara, como en la referencia
local PLANK_DARK = Color3.fromRGB(190, 150, 100)
local ROOF = Color3.fromRGB(225, 55, 55)
local DOOR = Color3.fromRGB(120, 70, 40)
local TREE_TRUNK = Color3.fromRGB(150, 90, 50)
local TREE_LEAVES = {
	Color3.fromRGB(90, 230, 90),
	Color3.fromRGB(60, 200, 120),
	Color3.fromRGB(150, 240, 80),
}
local BUSH_COLORS = {
	Color3.fromRGB(70, 210, 90),
	Color3.fromRGB(120, 235, 80),
}
local GEM_COLORS = {
	Color3.fromRGB(255, 80, 160),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(80, 230, 255),
	Color3.fromRGB(180, 110, 255),
	Color3.fromRGB(255, 120, 40),
}
local WHEEL_COLOR = Color3.fromRGB(255, 200, 60)
local BOARD_COLOR = Color3.fromRGB(60, 120, 255)
local POST_COLOR = Color3.fromRGB(90, 90, 110)

type HeightAt = (x: number, z: number) -> number

-- Superficie real del terreno en (x, z), medida con un raycast. Si no hay terreno, usa la altura calculada.
local function surfaceY(x: number, z: number, fallback: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), params)
	if hit ~= nil then
		return hit.Position.Y
	end
	return fallback
end

-- Pieza ancla: caja, esfera o cilindro. Todas quedan ancladas y con color plano.
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.Size = size
	piece.CFrame = cf
	piece.Color = color
	piece.Material = material or Enum.Material.SmoothPlastic
	if shape ~= nil then
		piece.Shape = shape
	end
	piece.Parent = parent
	return piece
end

-- Disco tumbado sobre el suelo. Un cilindro apunta a lo largo de X; girarlo 90° en Z lo deja plano.
local function flatDisc(parent: Instance, name: string, radius: number, thickness: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	return part(parent, name, Vector3.new(thickness, radius * 2, radius * 2), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
end

-- Chispas o luciérnagas: un ancla invisible con un emisor de partículas.
local function emitter(parent: Instance, position: Vector3, color: Color3, rate: number, speed: number, lifetime: number, spread: number)
	local anchor = part(parent, "Ambiente", Vector3.new(0.5, 0.5, 0.5), CFrame.new(position), color)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(color)
	particles.LightEmission = 1
	particles.Size = NumberSequence.new(0.35)
	particles.Rate = rate
	particles.Speed = NumberRange.new(speed * 0.5, speed)
	particles.Lifetime = NumberRange.new(lifetime * 0.7, lifetime)
	particles.SpreadAngle = Vector2.new(spread, spread)
	particles.Parent = anchor
	return anchor
end

-- Cartel con texto en la cara frontal de una pieza.
local function sign(piece: BasePart, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = piece
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Text = text
	label.Parent = gui
end

-- Cabaña de tejado a dos aguas. La puerta mira a `facing` contrario, o sea hacia la plaza.
-- `scale` agranda toda la cabaña (las casas de modalidad y la tienda son más grandes).
local function cabin(parent: Instance, name: string, position: Vector3, facing: Vector3, scale: number): Vector3
	local yaw = math.atan2(-facing.X, -facing.Z)
	local cf = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local s = scale
	part(parent, `{name}Cuerpo`, Vector3.new(6, 5, 6) * s, cf * CFrame.new(0, 2.5 * s, 0), WOOD, Enum.Material.Wood)
	part(parent, `{name}Puerta`, Vector3.new(1.6, 3, 0.3) * s, cf * CFrame.new(0, 1.5 * s, 3.05 * s), DOOR, Enum.Material.Wood)
	part(parent, `{name}Ventana`, Vector3.new(1.4, 1.4, 0.2) * s, cf * CFrame.new(-2 * s, 3 * s, 3.05 * s), Color3.fromRGB(255, 240, 180), Enum.Material.Neon)
	part(parent, `{name}Ventana`, Vector3.new(1.4, 1.4, 0.2) * s, cf * CFrame.new(2 * s, 3 * s, 3.05 * s), Color3.fromRGB(255, 240, 180), Enum.Material.Neon)
	-- Tablones: tres franjas horizontales oscuras en la fachada y en el fondo, como en la referencia.
	for _, zSign in { 1, -1 } do
		for _, y in { 1.4, 2.8, 4.2 } do
			part(parent, `{name}Tablon`, Vector3.new(6.1, 0.18, 0.2) * s, cf * CFrame.new(0, y * s, zSign * 3.06 * s), PLANK_DARK, Enum.Material.Wood)
		end
	end
	-- Tejado en A: dos faldones más empinados (42°) que se juntan en la cumbre.
	part(parent, `{name}TejadoA`, Vector3.new(6.6, 0.6, 4.6) * s, cf * CFrame.new(0, 7.2 * s, -2.2 * s) * CFrame.Angles(math.rad(-42), 0, 0), ROOF)
	part(parent, `{name}TejadoB`, Vector3.new(6.6, 0.6, 4.6) * s, cf * CFrame.new(0, 7.2 * s, 2.2 * s) * CFrame.Angles(math.rad(42), 0, 0), ROOF)
	-- Devuelve el centro de la puerta, donde se coloca el pad o el cartel.
	return (cf * CFrame.new(0, 0, 3.05 * s)).Position
end

-- Árbol de copa redonda en tres bolas.
local function tree(parent: Instance, position: Vector3, rng: Random)
	part(parent, "ArbolTronco", Vector3.new(4, 1.2, 1.2), CFrame.new(position + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), TREE_TRUNK, Enum.Material.Wood, Enum.PartType.Cylinder)
	local leaves = TREE_LEAVES[rng:NextInteger(1, #TREE_LEAVES)]
	part(parent, "ArbolCopa", Vector3.new(6, 6, 6), CFrame.new(position + Vector3.new(0, 6, 0)), leaves, Enum.Material.Grass, Enum.PartType.Ball)
	part(parent, "ArbolCopaAlta", Vector3.new(4, 4, 4), CFrame.new(position + Vector3.new(0, 9, 0)), leaves, Enum.Material.Grass, Enum.PartType.Ball)
end

-- Seto redondo del borde.
local function bush(parent: Instance, position: Vector3, rng: Random)
	local color = BUSH_COLORS[rng:NextInteger(1, #BUSH_COLORS)]
	local size = rng:NextNumber(5, 7)
	part(parent, "Seto", Vector3.new(size, size, size), CFrame.new(position + Vector3.new(0, size * 0.4, 0)), color, Enum.Material.Grass, Enum.PartType.Ball)
end

-- Fuente central grande: escalones de piedra, cuenco con agua y chorro con chispas.
local ROAD = Color3.fromRGB(196, 186, 170)
local LAMP_IRON = Color3.fromRGB(60, 60, 70)
local LAMP_GLOW = Color3.fromRGB(255, 225, 150)
local FLOWER_COLORS = {
	Color3.fromRGB(255, 80, 160),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(80, 230, 255),
	Color3.fromRGB(180, 110, 255),
	Color3.fromRGB(255, 120, 40),
}

-- Farola de hierro con bombilla cálida. La luz es suave para no saturar la plaza.
local function lamp(parent: Instance, position: Vector3)
	part(parent, "Farola", Vector3.new(0.8, 8, 0.8), CFrame.new(position + Vector3.new(0, 4, 0)), LAMP_IRON, Enum.Material.Metal)
	local bulb = part(parent, "FarolaLuz", Vector3.new(2, 2, 2), CFrame.new(position + Vector3.new(0, 8.8, 0)), LAMP_GLOW, Enum.Material.Neon, Enum.PartType.Ball)
	bulb.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = LAMP_GLOW
	light.Range = 16
	light.Brightness = 0.6
	light.Parent = bulb
end

-- Macizo circular de césped con siete flores de neón alrededor.
local function flowerBed(parent: Instance, center: Vector3, index: number)
	flatDisc(parent, "Macizo", 2.6, 0.5, center + Vector3.new(0, 0.3, 0), Color3.fromRGB(70, 160, 70), Enum.Material.Grass)
	for k = 0, 6 do
		local angle = k * math.pi * 2 / 7
		local spot = center + Vector3.new(math.cos(angle) * 2.2, 0.9, math.sin(angle) * 2.2)
		part(parent, "Flor", Vector3.new(1.1, 1.1, 1.1), CFrame.new(spot), FLOWER_COLORS[(index + k) % #FLOWER_COLORS + 1], Enum.Material.Neon, Enum.PartType.Ball)
	end
end

-- Camino de tierra plano entre dos puntos del suelo del hub.
local function road(hub: Instance, a: Vector2, b: Vector2, heightAt: HeightAt)
	local mid = (a + b) / 2
	local delta = b - a
	local dir = delta.Unit
	local y = heightAt(mid.X, mid.Y) + 0.35
	local cf = CFrame.lookAt(Vector3.new(mid.X, y, mid.Y), Vector3.new(mid.X, y, mid.Y) + Vector3.new(dir.X, 0, dir.Y))
	part(hub, "Camino", Vector3.new(4, 0.3, delta.Magnitude), cf, ROAD, Enum.Material.Cobblestone)
end

-- Fuente azul de cinco pisos: cada piso es un disco de piedra más estrecho que el de abajo,
-- con una lámina de agua encima. Un pilar central la sostiene y un chorro sale por arriba.
local FOUNTAIN_TIERS = { 10, 7.8, 5.8, 4.0, 2.4 }
local function fountain(hub: Instance, center: Vector3)
	local count = #FOUNTAIN_TIERS
	for index, radius in FOUNTAIN_TIERS do
		local base = 0.4 + (index - 1) * 1.8
		flatDisc(hub, `FuentePiso{index}`, radius, 1, center + Vector3.new(0, base + 0.5, 0), if index % 2 == 1 then FOUNTAIN_BLUE else FOUNTAIN_BLUE_DARK, Enum.Material.Marble)
		flatDisc(hub, `FuenteAgua{index}`, radius - 1.2, 0.25, center + Vector3.new(0, base + 1.05, 0), WATER_COLOR, Enum.Material.Neon)
	end
	local top = 0.4 + (count - 1) * 1.8 + 1.2
	part(hub, "FuentePilar", Vector3.new(1.2, top - 1.2, 1.2), CFrame.new(center + Vector3.new(0, (top + 1.2) / 2, 0)), FOUNTAIN_BLUE_DARK, Enum.Material.Marble)
	emitter(hub, center + Vector3.new(0, top + 1.4, 0), WATER_COLOR, 14, 5, 1.6, 22)
end

-- ---------- Puntos de interés ----------
-- Cada uno se construye en tamaño base alrededor del origen local, con la puerta o la cara hacia +X (la plaza),
-- y luego se agranda y se coloca en su punta de la isla (ver placeLandmark).

-- Piedras grandes en el borde del círculo de arena, como en la referencia.
local function stoneRing(model: Model, radius: number, groundY: number, rng: Random)
	local count = 20
	for index = 0, count - 1 do
		local angle = index * 2 * math.pi / count + rng:NextNumber(-0.05, 0.05)
		local position = Vector3.new(math.cos(angle) * radius, groundY + 0.5, math.sin(angle) * radius)
		flatDisc(model, "PiedraBorde", rng:NextNumber(1, 1.6), 0.5, position, STONE_COLORS[index % #STONE_COLORS + 1], Enum.Material.Slate)
	end
end

-- Tres casas de modalidad en fila, con un pad delante de cada una que lleva a su lobby.
local function buildModes(model: Model, groundY: number)
	for _, mode in MODE_HOUSES do
		cabin(model, `Casa{mode.id}`, Vector3.new(0, groundY, mode.z), Vector3.new(-1, 0, 0), HOUSE_SCALE)
		local pad = PadBuilder.build(model, `Entrada_{mode.id}`, Vector3.new(PAD_OFFSET, groundY + 0.6, mode.z), mode.color, mode.destination and mode.id or "Próximamente")
		if mode.destination ~= nil then
			local destination = if mode.destination == "wave" then ModeLayout.waveLobby() else ModeLayout.bossLobby()
			PadBuilder.prompt(pad, `Ir a {mode.id}`, "Modalidad", function(player: Player)
				local character = player.Character
				if character ~= nil then
					character:PivotTo(CFrame.new(destination))
				end
			end)
		end
	end
	-- Calle de adoquín delante de los pads.
	local street = PAD_OFFSET + 5
	local mid = Vector3.new(street, groundY + 0.35, 0)
	part(model, "Calle", Vector3.new(4, 0.3, 34), CFrame.new(mid), ROAD, Enum.Material.Cobblestone)
end

-- Tienda: casa grande con cartel y un prompt que abre la ventana de tienda (Bootstrap lo conecta).
local SHOP_SCALE = 2.1
local function buildShop(model: Model, groundY: number)
	local door = cabin(model, "Tienda", Vector3.new(0, groundY, 0), Vector3.new(-1, 0, 0), SHOP_SCALE)
	-- El cartel va sobre la puerta, de cara a la plaza (+X).
	local board = part(model, "TiendaCartel", Vector3.new(6, 1.6, 0.3), CFrame.new(door + Vector3.new(0.2, 4.4 * SHOP_SCALE, 0)) * CFrame.Angles(0, math.rad(-90), 0), BOARD_COLOR)
	sign(board, "TIENDA")
	local mark = part(model, "TiendaMarca", Vector3.new(0.6, 0.6, 0.6), CFrame.new(door + Vector3.new(0, 0.3, 0)), Color3.fromRGB(255, 220, 90), Enum.Material.Neon)
	mark.Transparency = 1
	mark.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PromptTienda"
	prompt.ActionText = "Abrir tienda"
	prompt.ObjectText = "Tienda"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = mark
	-- Adoquín desde la puerta hacia la plaza.
	part(model, "CaminoTienda", Vector3.new(14, 0.3, 4), CFrame.new(door + Vector3.new(7, 0.35, 0)), ROAD, Enum.Material.Cobblestone)
end

-- Ruleta grande: disco vertical sobre un poste alto, con la cara hacia la plaza (+X) y un pedestal de piedra.
local WHEEL_RADIUS = 7
local function buildWheel(model: Model, groundY: number)
	local wheelHeight = 10
	flatDisc(model, "RuletaBase", 6, 1, Vector3.new(0, groundY + 0.5, 0), Color3.fromRGB(190, 200, 215), Enum.Material.Marble)
	part(model, "RuletaPoste", Vector3.new(1.2, wheelHeight, 1.2), CFrame.new(0, groundY + wheelHeight / 2, 0), POST_COLOR, Enum.Material.Metal)
	-- El cilindro apunta a lo largo de X: sin girar, su cara mira a la plaza.
	local wheel = part(model, "Ruleta", Vector3.new(1.2, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2), CFrame.new(0, groundY + wheelHeight + 1, 0), WHEEL_COLOR, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	for index = 0, 7 do
		local angle = math.rad(index * 45)
		part(model, "RuletaSector", Vector3.new(1.4, 1.6, 1.6), wheel.CFrame * CFrame.new(0.2, math.sin(angle) * (WHEEL_RADIUS - 0.4), math.cos(angle) * (WHEEL_RADIUS - 0.4)), STONE_COLORS[index % #STONE_COLORS + 1], Enum.Material.Neon, Enum.PartType.Ball)
	end
end

-- Tres tableros de clasificación de cara a la plaza, y un montón de gemas de colores detrás, como en la referencia.
local function buildBoards(model: Model, groundY: number, rng: Random)
	local boards = { { z = -9, text = "VICTORIAS" }, { z = 0, text = "CLASIFICACIÓN" }, { z = 9, text = "RANGO" } }
	for _, info in boards do
		part(model, "TableroPoste", Vector3.new(0.8, 6, 0.8), CFrame.new(0, groundY + 3, info.z), POST_COLOR, Enum.Material.Metal)
		-- La cara con texto (-Z local) gira -90° para mirar a +X.
		local board = part(model, "Clasificacion", Vector3.new(7, 4, 0.6), CFrame.new(0, groundY + 7.5, info.z) * CFrame.Angles(0, math.rad(-90), 0), BOARD_COLOR)
		sign(board, info.text)
	end
	for index = 0, 13 do
		local row = index // 7
		local column = index % 7
		local offset = Vector3.new(-6 - row * 2.2 + rng:NextNumber(-0.3, 0.3), 1 + row * 1.6 + (column % 2) * 0.5, (column - 3) * 1.9)
		part(model, "Gema", Vector3.new(2, 2, 2), CFrame.new(Vector3.new(0, groundY, 0) + offset), GEM_COLORS[index % #GEM_COLORS + 1], Enum.Material.Neon, Enum.PartType.Ball)
	end
end

-- Escala un modelo alrededor de su origen conservando las distancias de interacción y los rótulos, y lo coloca.
-- Los botones, rótulos y luces se fijan a mano porque no se sabe si ScaleTo los agranda.
local function scaleAndPlace(model: Model, groundY: number, scale: number, placement: CFrame)
	local reach: { [ProximityPrompt]: number } = {}
	local offsets: { [BillboardGui]: Vector3 } = {}
	local distances: { [BillboardGui]: number } = {}
	local lights: { [PointLight]: number } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			reach[descendant] = descendant.MaxActivationDistance
		elseif descendant:IsA("BillboardGui") then
			offsets[descendant] = descendant.StudsOffset
			distances[descendant] = descendant.MaxDistance
		elseif descendant:IsA("PointLight") then
			lights[descendant] = descendant.Range
		end
	end
	model.WorldPivot = CFrame.new(0, groundY, 0)
	model:ScaleTo(scale)
	for prompt, distance in reach do
		prompt.MaxActivationDistance = distance * scale
	end
	for gui, offset in offsets do
		gui.StudsOffset = offset * scale
		gui.MaxDistance = distances[gui] * scale
	end
	for light, range in lights do
		light.Range = math.min(range * scale, 60)
	end
	model:PivotTo(placement)
end

function HubBuilder.build(heightAt: HeightAt)
	-- Todo el hub usa la superficie medida, no la altura calculada (ver surfaceY).
	local calculated = heightAt
	heightAt = function(x: number, z: number): number
		return surfaceY(x, z, calculated(x, z))
	end
	local previous = workspace:FindFirstChild("Hub")
	if previous ~= nil then
		previous:Destroy()
	end
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = workspace

	local rng = Random.new(42) -- semilla fija: siempre el mismo hub
	-- Todas las zonas planas están a FLAT_HEIGHT: los modelos se construyen en el origen y se colocan sin desfase vertical.
	local groundY = heightAt(0, 0)
	local center = Vector3.new(0, groundY, 0)

	-- ---------- Plaza central: solo la fuente y su entorno ----------
	local plaza = Instance.new("Model")
	plaza.Name = "Plaza"
	plaza.Parent = hub

	-- Suelo de arena, círculo de piedra bajo la fuente y piedras grises en anillo, como la referencia.
	flatDisc(plaza, "Plaza", 30, 0.4, center + Vector3.new(0, 0.2, 0), SAND, Enum.Material.Sand)
	flatDisc(plaza, "PlazaCentro", 17, 0.25, center + Vector3.new(0, 0.45, 0), Color3.fromRGB(190, 200, 215), Enum.Material.Cobblestone)
	for index = 0, 13 do
		local angle = math.rad(index * 360 / 14 + 8)
		flatDisc(plaza, "PiedraAnillo", 1.8, 0.3, center + Vector3.new(math.cos(angle) * 26, 0.5, math.sin(angle) * 26), Color3.fromRGB(150, 150, 160), Enum.Material.Slate)
	end
	for index = 0, 11 do
		local angle = math.rad(index * 30 + 15)
		lamp(plaza, center + Vector3.new(math.cos(angle) * 22, 0.5, math.sin(angle) * 22))
	end
	for index = 0, 5 do
		local angle = math.rad(index * 60)
		flowerBed(plaza, center + Vector3.new(math.cos(angle) * 21, 0.5, math.sin(angle) * 21), index)
	end
	-- Círculos grandes de arena con piedras en el borde de la plaza (30°, 90° y 330°).
	for _, degrees in { 30, 90, 330 } do
		local angle = math.rad(degrees)
		local spot = center + Vector3.new(math.cos(angle) * 36, 0.3, math.sin(angle) * 36)
		flatDisc(plaza, "ArenaGrande", 9, 0.3, spot, SAND, Enum.Material.Sand)
		for stone = 0, 5 do
			local a = stone * math.pi / 3
			flatDisc(plaza, "PiedraArena", 1, 0.4, spot + Vector3.new(math.cos(a) * 4.5, 0.4, math.sin(a) * 4.5), Color3.fromRGB(150, 150, 160), Enum.Material.Slate)
		end
	end
	for index = 0, 15 do
		local angle = math.rad(index * 22.5)
		flatDisc(plaza, "Piedra", 1.2, 0.4, center + Vector3.new(math.cos(angle) * 14, 0.6, math.sin(angle) * 14), STONE_COLORS[(index % #STONE_COLORS) + 1], Enum.Material.Slate)
	end
	for index = 1, 9 do
		local angle = math.rad(index * 40)
		flatDisc(plaza, "Parterre", 2, 0.3, center + Vector3.new(math.cos(angle) * 11, 0.5, math.sin(angle) * 11), Color3.fromRGB(255, 120, 180), Enum.Material.Grass)
	end
	fountain(plaza, center)

	-- Árboles de copa redonda en un anillo alrededor de la plaza y luciérnagas por encima.
	for index = 0, 11 do
		local angle = math.rad(index * 30 + 15)
		local radius = rng:NextNumber(41, 43)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		tree(plaza, Vector3.new(x, heightAt(x, z), z), rng)
	end
	for index = 0, 7 do
		local angle = math.rad(index * 45 + rng:NextNumber(-10, 10))
		local radius = rng:NextNumber(8, 30)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		emitter(plaza, Vector3.new(x, heightAt(x, z) + 3, z), Color3.fromRGB(240, 255, 120), 2, 1, 4, 180)
	end
	scaleAndPlace(plaza, groundY, MapLayout.HUB_SCALE, CFrame.new(center))

	-- ---------- Puntos de interés, uno en cada punta ----------
	local builders: { [string]: (Model) -> () } = {
		modes = function(model)
			buildModes(model, groundY)
		end,
		shop = function(model)
			buildShop(model, groundY)
		end,
		wheel = function(model)
			buildWheel(model, groundY)
		end,
		boards = function(model)
			buildBoards(model, groundY, rng)
		end,
	}
	for _, landmark in MapLayout.landmarks() do
		local model = Instance.new("Model")
		model.Name = `Zona_{landmark.id}`
		model.Parent = hub
		builders[landmark.kind](model)
		-- Círculo de piedras en el borde de la arena (el terreno ya es arena dentro del radio).
		stoneRing(model, landmark.radius / landmark.scale * 0.93, groundY, rng)
		-- La cara/puerta del modelo mira a +X local: se gira para que mire a la plaza.
		local inward = -landmark.center.Unit
		local yaw = math.atan2(-inward.Y, inward.X)
		scaleAndPlace(model, groundY, landmark.scale, CFrame.new(landmark.center.X, groundY, landmark.center.Y) * CFrame.Angles(0, yaw, 0))
	end
end

return HubBuilder

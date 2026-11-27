--!strict
--[[
	Hub de entrada. Disposición (vista desde la fuente, con el norte arriba = -Z):
	  Norte: gran ruleta.            Centro: fuente grande, con chispas.
	  Oeste: tres casas grandes de modalidad (Oleadas, Jefes, próximamente).
	  Este: casa grande de tienda. El jugador aparece al lado de la fuente, por la derecha.
	  Sur: varios tableros de clasificación.
	Se rehace en cada arranque. Los carteles y los pads de entrada son los que usan los servicios.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local ModeLayout = require(ServerScriptService.World.ModeLayout)
local PadBuilder = require(ServerScriptService.World.PadBuilder)
local MapLayout = require(ServerScriptService.World.MapLayout)

local HubBuilder = {}

local HOUSE_X = -26 -- las casas de modalidad van en fila al oeste
local HOUSE_SCALE = 1.6
local SHOP_X = 27
local WHEEL_Z = -20
local BOARD_Z = 25
local PAD_OFFSET = 9.5 -- distancia del pad a la casa, hacia la fuente

-- Casas de modalidad, de norte a sur. Cada una tiene un pad delante que lleva a su lobby.
local MODE_HOUSES = {
	{ id = "Oleadas", z = -16, color = Color3.fromRGB(90, 230, 110), destination = "wave" },
	{ id = "Jefes", z = 0, color = Color3.fromRGB(255, 90, 90), destination = "boss" },
	{ id = "Proximamente", z = 16, color = Color3.fromRGB(150, 150, 165), destination = nil },
}

local SAND = Color3.fromRGB(250, 220, 150)
local STONE_COLORS = {
	Color3.fromRGB(200, 200, 215),
	Color3.fromRGB(255, 190, 120),
	Color3.fromRGB(170, 220, 255),
}
local FOUNTAIN_STONE = Color3.fromRGB(120, 150, 185)
local WATER_COLOR = Color3.fromRGB(120, 200, 255)
local WOOD = Color3.fromRGB(205, 140, 80)
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
	part(parent, `{name}TejadoA`, Vector3.new(6.6, 0.6, 4.2) * s, cf * CFrame.new(0, 6.9 * s, -2.1 * s) * CFrame.Angles(math.rad(-35), 0, 0), ROOF)
	part(parent, `{name}TejadoB`, Vector3.new(6.6, 0.6, 4.2) * s, cf * CFrame.new(0, 6.9 * s, 2.1 * s) * CFrame.Angles(math.rad(35), 0, 0), ROOF)
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

local function fountain(hub: Instance, center: Vector3)
	flatDisc(hub, "FuenteEscalon", 9, 0.6, center + Vector3.new(0, 0.3, 0), FOUNTAIN_STONE, Enum.Material.Slate)
	flatDisc(hub, "FuenteCuenco", 7, 1.2, center + Vector3.new(0, 1.2, 0), FOUNTAIN_STONE, Enum.Material.Marble)
	flatDisc(hub, "FuenteAguaBaja", 5.6, 0.3, center + Vector3.new(0, 1.9, 0), WATER_COLOR, Enum.Material.Neon)
	part(hub, "FuentePilar", Vector3.new(1.4, 4.4, 1.4), CFrame.new(center + Vector3.new(0, 4.2, 0)), FOUNTAIN_STONE, Enum.Material.Marble)
	flatDisc(hub, "FuenteCuencoAlto", 3.6, 0.9, center + Vector3.new(0, 5.2, 0), FOUNTAIN_STONE, Enum.Material.Marble)
	flatDisc(hub, "FuenteAguaAlta", 2.9, 0.3, center + Vector3.new(0, 5.8, 0), WATER_COLOR, Enum.Material.Neon)
	flatDisc(hub, "FuenteCopa", 1.6, 0.5, center + Vector3.new(0, 7.6, 0), FOUNTAIN_STONE, Enum.Material.Marble)
	emitter(hub, center + Vector3.new(0, 8.4, 0), WATER_COLOR, 12, 4, 1.4, 25)
end

-- Zonas ocupadas por edificios: ni árboles ni setos dentro.
local function blocked(x: number, z: number): boolean
	if x < -18 and x > -36 and z > -24 and z < 24 then
		return true -- casas de modalidad
	end
	if x > 18 and x < 36 and z > -8 and z < 8 then
		return true -- tienda
	end
	if math.abs(x) < 9 and z < -14 and z > -28 then
		return true -- ruleta
	end
	if math.abs(x) < 14 and z > 20 and z < 30 then
		return true -- tableros
	end
	return false
end

function HubBuilder.build(heightAt: HeightAt)
	local previous = workspace:FindFirstChild("Hub")
	if previous ~= nil then
		previous:Destroy()
	end
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	hub.Parent = workspace

	local rng = Random.new(42) -- semilla fija: siempre el mismo hub
	local groundY = heightAt(0, 0)
	local center = Vector3.new(0, groundY, 0)

	-- Plaza empedrada: anillo de adoquín y círculo de mármol en el centro, con farolas y macizos de flores alrededor.
	flatDisc(hub, "Plaza", 26, 0.4, center + Vector3.new(0, 0.2, 0), Color3.fromRGB(196, 186, 170), Enum.Material.Cobblestone)
	flatDisc(hub, "PlazaCentro", 18, 0.25, center + Vector3.new(0, 0.45, 0), Color3.fromRGB(236, 230, 220), Enum.Material.Marble)
	for index = 0, 11 do
		local angle = math.rad(index * 30 + 15)
		lamp(hub, center + Vector3.new(math.cos(angle) * 22, 0.5, math.sin(angle) * 22))
	end
	for index = 0, 5 do
		local angle = math.rad(index * 60)
		flowerBed(hub, center + Vector3.new(math.cos(angle) * 21, 0.5, math.sin(angle) * 21), index)
	end
	for index = 0, 2 do
		local angle = math.rad(60 + index * 120)
		flatDisc(hub, "Arena", 5, 0.3, center + Vector3.new(math.cos(angle) * 17, 0.3, math.sin(angle) * 17), SAND, Enum.Material.Sand)
	end
	for index = 0, 15 do
		local angle = math.rad(index * 22.5)
		local position = center + Vector3.new(math.cos(angle) * 14, 0.6, math.sin(angle) * 14)
		flatDisc(hub, "Piedra", 1.2, 0.4, position, STONE_COLORS[(index % #STONE_COLORS) + 1], Enum.Material.Slate)
	end

	fountain(hub, center)

	-- Caminos de tierra como en la referencia: una calle por las entradas del oeste y un camino a la tienda.
	road(hub, Vector2.new(HOUSE_X + PAD_OFFSET, -16), Vector2.new(HOUSE_X + PAD_OFFSET, 16), heightAt)
	road(hub, Vector2.new(HOUSE_X + PAD_OFFSET, 0), Vector2.new(-4, 0), heightAt)
	road(hub, Vector2.new(4, 0), Vector2.new(SHOP_X - 2, 0), heightAt)

	-- Casas de modalidad al oeste, con la puerta hacia la fuente y un pad delante.
	for _, mode in MODE_HOUSES do
		local position = Vector3.new(HOUSE_X, heightAt(HOUSE_X, mode.z), mode.z)
		cabin(hub, `Casa{mode.id}`, position, Vector3.new(HOUSE_X, 0, mode.z), HOUSE_SCALE)
		local padX = HOUSE_X + PAD_OFFSET
		local pad = PadBuilder.build(hub, `Entrada_{mode.id}`, Vector3.new(padX, heightAt(padX, mode.z) + 0.6, mode.z), mode.color, mode.destination and mode.id or "Próximamente")
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

	-- Tienda: casa grande al este. Tiene un cartel y un prompt que abre la ventana de tienda (Bootstrap lo conecta).
	local shopPosition = Vector3.new(SHOP_X, heightAt(SHOP_X, 0), 0)
	local shopDoor = cabin(hub, "Tienda", shopPosition, Vector3.new(SHOP_X, 0, 0), HOUSE_SCALE)
	local shopSign = part(hub, "TiendaCartel", Vector3.new(6, 1.6, 0.3), CFrame.new(shopDoor + Vector3.new(0, 4.4 * HOUSE_SCALE, 0.2)) * CFrame.Angles(0, math.rad(180), 0), BOARD_COLOR)
	sign(shopSign, "TIENDA")
	local shopPad = part(hub, "TiendaMarca", Vector3.new(0.6, 0.6, 0.6), CFrame.new(shopDoor + Vector3.new(0, 0.3, 0)), Color3.fromRGB(255, 220, 90), Enum.Material.Neon)
	shopPad.Transparency = 1
	shopPad.CanCollide = false
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.Name = "PromptTienda"
	shopPrompt.ActionText = "Abrir tienda"
	shopPrompt.ObjectText = "Tienda"
	shopPrompt.MaxActivationDistance = 10
	shopPrompt.RequiresLineOfSight = false
	shopPrompt.Parent = shopPad

	-- Ruleta al norte: disco vertical sobre poste, con el eje hacia la plaza.
	local wheelBase = Vector3.new(0, heightAt(0, WHEEL_Z), WHEEL_Z)
	part(hub, "RuletaPoste", Vector3.new(1, 4, 1), CFrame.new(wheelBase + Vector3.new(0, 2, 0)), POST_COLOR, Enum.Material.Metal)
	local wheel = part(hub, "Ruleta", Vector3.new(1.2, 9, 9), CFrame.new(wheelBase + Vector3.new(0, 6.5, 0)) * CFrame.Angles(0, math.rad(90), 0), WHEEL_COLOR, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	for index = 1, 4 do
		local angle = math.rad(index * 90)
		part(hub, "RuletaSector", Vector3.new(1.1, 1.2, 1.2), wheel.CFrame * CFrame.new(0, math.sin(angle) * 3.6, math.cos(angle) * 3.6), STONE_COLORS[index % #STONE_COLORS + 1], Enum.Material.Neon, Enum.PartType.Ball)
	end

	-- Tableros de clasificación al sur, de cara a la plaza.
	local boards = { { x = -9, text = "VICTORIAS" }, { x = 0, text = "CLASIFICACIÓN" }, { x = 9, text = "RANGO" } }
	for _, info in boards do
		local base = Vector3.new(info.x, heightAt(info.x, BOARD_Z), BOARD_Z)
		part(hub, "TableroPoste", Vector3.new(0.8, 6, 0.8), CFrame.new(base + Vector3.new(0, 3, 0)), POST_COLOR, Enum.Material.Metal)
		local board = part(hub, "Clasificacion", Vector3.new(7, 4, 0.6), CFrame.new(base + Vector3.new(0, 7.5, 0)), BOARD_COLOR)
		sign(board, info.text)
	end

	-- Gemas de colores en un montón al suroeste.
	local gemBase = Vector3.new(-30, heightAt(-30, 30), 30)
	for index, color in GEM_COLORS do
		local offset = Vector3.new((index - 3) * 1.6, 1 + (index % 2) * 0.8, rng:NextNumber(-0.5, 0.5))
		part(hub, "Gema", Vector3.new(2, 2, 2), CFrame.new(gemBase + offset), color, Enum.Material.Neon, Enum.PartType.Ball)
	end

	-- Parterres de flores alrededor de la fuente (no en el lado del spawn).
	for index = 1, 9 do
		local angle = math.rad(index * 40)
		local position = center + Vector3.new(math.cos(angle) * 11, 0.5, math.sin(angle) * 11)
		flatDisc(hub, "Parterre", 2, 0.3, position, Color3.fromRGB(255, 120, 180), Enum.Material.Grass)
	end

	-- Árboles en el borde de la plaza, sin tapar edificios.
	for index = 0, 17 do
		local angle = math.rad(index * 20 + rng:NextNumber(-4, 4))
		local radius = rng:NextNumber(33, 36)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		if not blocked(x, z) then
			tree(hub, Vector3.new(x, heightAt(x, z), z), rng)
		end
	end

	-- Setos en el anillo exterior: cierran la plaza como un islote.
	for index = 0, 23 do
		local angle = math.rad(index * 15 + rng:NextNumber(-3, 3))
		local radius = rng:NextNumber(42, 46)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		bush(hub, Vector3.new(x, heightAt(x, z), z), rng)
	end

	-- Luciérnagas repartidas por la plaza.
	for index = 0, 7 do
		local angle = math.rad(index * 45 + rng:NextNumber(-10, 10))
		local radius = rng:NextNumber(8, 30)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		emitter(hub, Vector3.new(x, heightAt(x, z) + 3, z), Color3.fromRGB(240, 255, 120), 2, 1, 4, 180)
	end
end

return HubBuilder

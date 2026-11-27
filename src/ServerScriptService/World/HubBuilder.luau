--!strict
--[[
	Hub de entrada, inspirado en la referencia: plaza de césped con círculos de arena, fuente central,
	cabañas de tejado rojo, árboles de copa redonda, setos en el borde, gemas, ruleta, tienda y tablero.
	Ambiente: chispas en la fuente y luciérnagas repartidas por la plaza.
	Se rehace en cada arranque. Los carteles de tienda y clasificación siguen siendo provisionales.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local ModeLayout = require(ServerScriptService.World.ModeLayout)
local PadBuilder = require(ServerScriptService.World.PadBuilder)

local HubBuilder = {}

-- Cabañas de modalidad: al norte de la plaza, en fila. Cada una tiene un pad delante que lleva a su lobby.
local MODE_CABINS = {
	{ id = "Oleadas", x = -18, color = Color3.fromRGB(90, 230, 110), destination = "wave" },
	{ id = "Jefes", x = -6, color = Color3.fromRGB(255, 90, 90), destination = "boss" },
	{ id = "Proximamente", x = 6, color = Color3.fromRGB(150, 150, 165), destination = nil },
	{ id = "Proximamente", x = 18, color = Color3.fromRGB(150, 150, 165), destination = nil },
}
local CABIN_Z = -30
local PAD_Z = -23.5

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

-- Tejado a dos aguas: dos bloques inclinados que se encuentran en la cumbrera.
local function cabin(parent: Instance, position: Vector3, facing: Vector3)
	-- Yaw para que la puerta (cara +Z local) mire hacia el centro de la plaza.
	local yaw = math.atan2(-facing.X, -facing.Z)
	local cf = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	part(parent, "CabinaCuerpo", Vector3.new(6, 5, 6), cf * CFrame.new(0, 2.5, 0), WOOD, Enum.Material.Wood)
	part(parent, "CabinaPuerta", Vector3.new(1.6, 3, 0.3), cf * CFrame.new(0, 1.5, 3.05), DOOR, Enum.Material.Wood)
	part(parent, "CabinaVentana", Vector3.new(1.4, 1.4, 0.2), cf * CFrame.new(-2, 3, 3.05), Color3.fromRGB(255, 240, 180), Enum.Material.Neon)
	part(parent, "CabinaVentana", Vector3.new(1.4, 1.4, 0.2), cf * CFrame.new(2, 3, 3.05), Color3.fromRGB(255, 240, 180), Enum.Material.Neon)
	part(parent, "CabinaTejadoA", Vector3.new(6.6, 0.6, 4.2), cf * CFrame.new(0, 6.9, -2.1) * CFrame.Angles(math.rad(-35), 0, 0), ROOF)
	part(parent, "CabinaTejadoB", Vector3.new(6.6, 0.6, 4.2), cf * CFrame.new(0, 6.9, 2.1) * CFrame.Angles(math.rad(35), 0, 0), ROOF)
end

-- Árbol de copa redonda en tres bolas, para que se lea como en la referencia.
local function tree(parent: Instance, position: Vector3, rng: Random)
	part(parent, "ArbolTronco", Vector3.new(4, 1.2, 1.2), CFrame.new(position + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), TREE_TRUNK, Enum.Material.Wood, Enum.PartType.Cylinder)
	local leaves = TREE_LEAVES[rng:NextInteger(1, #TREE_LEAVES)]
	part(parent, "ArbolCopa", Vector3.new(6, 6, 6), CFrame.new(position + Vector3.new(0, 6, 0)), leaves, Enum.Material.Grass, Enum.PartType.Ball)
	part(parent, "ArbolCopaAlta", Vector3.new(4, 4, 4), CFrame.new(position + Vector3.new(0, 9, 0)), leaves, Enum.Material.Grass, Enum.PartType.Ball)
end

-- Seto redondo: el borde del hub, para que la plaza parezca un islote.
local function bush(parent: Instance, position: Vector3, rng: Random)
	local color = BUSH_COLORS[rng:NextInteger(1, #BUSH_COLORS)]
	local size = rng:NextNumber(5, 7)
	part(parent, "Seto", Vector3.new(size, size, size), CFrame.new(position + Vector3.new(0, size * 0.4, 0)), color, Enum.Material.Grass, Enum.PartType.Ball)
end

-- Cartel con texto en una cara de una pieza. Sirve para tienda y clasificación.
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

-- Fuente central, grande: escalón de piedra, cuenco inferior con agua, pilar con cuenco
-- superior y chorro. Es el punto focal de la plaza, como en la referencia.
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

function HubBuilder.build(heightAt: HeightAt)
	-- El hub lo genera este script: se rehace en cada arranque para que los cambios de código se vean.
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

	-- Plaza de césped con círculos de arena y anillo de piedras de colores.
	flatDisc(hub, "Plaza", 26, 0.4, center + Vector3.new(0, 0.2, 0), Color3.fromRGB(110, 220, 90), Enum.Material.Grass)
	for index = 0, 2 do
		local angle = math.rad(60 + index * 120)
		local spot = center + Vector3.new(math.cos(angle) * 17, 0.3, math.sin(angle) * 17)
		flatDisc(hub, "Arena", 5, 0.3, spot, SAND, Enum.Material.Sand)
	end
	for index = 0, 15 do
		local angle = math.rad(index * 22.5)
		local position = center + Vector3.new(math.cos(angle) * 14, 0.6, math.sin(angle) * 14)
		flatDisc(hub, "Piedra", 1.2, 0.4, position, STONE_COLORS[(index % #STONE_COLORS) + 1], Enum.Material.Slate)
	end

	-- Fuente en el centro, con chispas.
	fountain(hub, center)

	-- Parterres de flores de colores entre la fuente y las cabañas.
	for index = 0, 9 do
		local angle = math.rad(index * 36)
		local position = center + Vector3.new(math.cos(angle) * 10, 0.5, math.sin(angle) * 10)
		flatDisc(hub, "Parterre", 2, 0.3, position, Color3.fromRGB(255, 120, 180), Enum.Material.Grass)
	end

	-- Cuatro cabañas de modalidad al norte, con la puerta hacia la plaza y un pad brillante delante.
	for _, mode in MODE_CABINS do
		local outward = Vector3.new(mode.x, 0, CABIN_Z).Unit
		cabin(hub, Vector3.new(mode.x, heightAt(mode.x, CABIN_Z), CABIN_Z), outward)
		local padY = heightAt(mode.x, PAD_Z) + 0.6
		local pad = PadBuilder.build(hub, `Entrada_{mode.id}`, Vector3.new(mode.x, padY, PAD_Z), mode.color, mode.destination and mode.id or "Próximamente")
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

	-- Árboles de copa redonda en el borde de la plaza.
	for index = 0, 11 do
		local angle = math.rad(index * 30 + rng:NextNumber(-6, 6))
		local radius = rng:NextNumber(30, 34)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		if z > -20 then -- el norte es de las cabañas de modalidad
			tree(hub, Vector3.new(x, heightAt(x, z), z), rng)
		end
	end

	-- Setos en un anillo exterior, que cierran la plaza como un islote.
	for index = 0, 23 do
		local angle = math.rad(index * 15 + rng:NextNumber(-3, 3))
		local radius = rng:NextNumber(42, 46)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		bush(hub, Vector3.new(x, heightAt(x, z), z), rng)
	end

	-- Grupo de gemas de colores, al estilo de los montones de la referencia.
	local gemBase = Vector3.new(-28, heightAt(-28, 4), 4)
	for index, color in GEM_COLORS do
		local offset = Vector3.new((index - 3) * 1.6, 1 + (index % 2) * 0.8, rng:NextNumber(-0.5, 0.5))
		part(hub, "Gema", Vector3.new(2, 2, 2), CFrame.new(gemBase + offset), color, Enum.Material.Neon, Enum.PartType.Ball)
	end

	-- Ruleta: disco vertical sobre un poste, con cuatro sectores de colores.
	local wheelBase = Vector3.new(16, heightAt(16, 0), 0)
	part(hub, "RuletaPoste", Vector3.new(1, 4, 1), CFrame.new(wheelBase + Vector3.new(0, 2, 0)), POST_COLOR, Enum.Material.Metal)
	local wheel = part(hub, "Ruleta", Vector3.new(1, 7, 7), CFrame.new(wheelBase + Vector3.new(0, 6.5, 0)), WHEEL_COLOR, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	for index = 1, 4 do
		local angle = math.rad(index * 90)
		part(hub, "RuletaSector", Vector3.new(1.1, 1, 1), wheel.CFrame * CFrame.new(0, math.sin(angle) * 2.8, math.cos(angle) * 2.8), STONE_COLORS[index % #STONE_COLORS + 1], Enum.Material.Neon, Enum.PartType.Ball)
	end

	-- Tablero de clasificación detrás de la plaza. La tienda está en el este (LandmarksBuilder).
	local boardBase = Vector3.new(30, heightAt(30, -14), -14)
	part(hub, "TableroPoste", Vector3.new(0.8, 6, 0.8), CFrame.new(boardBase + Vector3.new(0, 3, 0)), POST_COLOR, Enum.Material.Metal)
	local board = part(hub, "Clasificacion", Vector3.new(12, 5, 0.6), CFrame.new(boardBase + Vector3.new(0, 8.5, 0)), BOARD_COLOR)
	sign(board, "CLASIFICACIÓN")

	-- Luciérnagas repartidas por la plaza: ambiente sin coste de física.
	for index = 0, 7 do
		local angle = math.rad(index * 45 + rng:NextNumber(-10, 10))
		local radius = rng:NextNumber(8, 30)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		emitter(hub, Vector3.new(x, heightAt(x, z) + 3, z), Color3.fromRGB(240, 255, 120), 2, 1, 4, 180)
	end
end

return HubBuilder

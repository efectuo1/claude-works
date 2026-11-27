--!strict
--[[
	Geometría de las modalidades: arena de oleadas (plataforma central, plataformas de aparición,
	puentes con barandilla y agua) y sala de jefes (lobby, puente y arena con pilares).
	Las medidas salen de ModeLayout. Se rehace en cada arranque dentro de workspace.Modos.
	Los pads de entrada los crean los servicios con PadBuilder dentro de la misma carpeta.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local ModeLayout = require(ServerScriptService.World.ModeLayout)
local MapLayout = require(ServerScriptService.World.MapLayout)

local ModeArenaBuilder = {}

local FOLDER_NAME = "Modos"
local WOOD = Color3.fromRGB(170, 120, 70)
local PLANK = Color3.fromRGB(200, 150, 95)
local WATER = Color3.fromRGB(70, 170, 255)
local RAIL = Color3.fromRGB(235, 235, 245)
local STONE = Color3.fromRGB(175, 175, 190)
local MARBLE = Color3.fromRGB(215, 205, 235)

-- Pieza anclada con color plano.
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.Size = size
	piece.CFrame = cf
	piece.Color = color
	piece.Material = material
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

-- Disco plano centrado en (center.X, y, center.Y). Un cilindro apunta a lo largo de X; se gira 90° en Z.
local function disc(parent: Instance, name: string, center: Vector2, radius: number, y: number, color: Color3, material: Enum.Material): Part
	local piece = part(parent, name, Vector3.new(0.6, radius * 2, radius * 2), CFrame.new(center.X, y, center.Y) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	piece.Shape = Enum.PartType.Cylinder
	return piece
end

-- Tablón entre dos puntos, con barandilla a cada lado. Las barandillas son sólidas: los mobs no se caen.
local function bridge(parent: Instance, from: Vector2, to: Vector2, width: number, y: number)
	local delta = to - from
	local length = delta.Magnitude
	local mid = (from + to) / 2
	local flatDir = Vector3.new(delta.X, 0, delta.Y).Unit
	local origin = Vector3.new(mid.X, y, mid.Y)
	local cf = CFrame.lookAt(origin, origin + flatDir)

	part(parent, "Puente", Vector3.new(width, 0.6, length), cf, PLANK, Enum.Material.Wood)
	for _, side in { -1, 1 } do
		part(parent, "Barandilla", Vector3.new(0.4, 2.4, length), cf * CFrame.new(side * (width / 2 - 0.2), 1.2, 0), RAIL, Enum.Material.SmoothPlastic)
	end
end

local BASE_SAND = Color3.fromRGB(230, 205, 150)
local BASE_STONE = Color3.fromRGB(150, 150, 165)
local RIM = Color3.fromRGB(225, 200, 150)
local ORANGE = Color3.fromRGB(230, 140, 60)
local LANTERN_GLOW = Color3.fromRGB(255, 200, 110)

-- Borde de piedra alrededor de un disco: bloques tangentes al círculo.
local function rim(parent: Instance, name: string, center: Vector2, radius: number, y: number)
	local count = math.max(12, math.floor(radius * 1.6))
	local segment = 2 * math.pi * radius / count
	for index = 0, count - 1 do
		local angle = index * 2 * math.pi / count
		local x = center.X + math.cos(angle) * radius
		local z = center.Y + math.sin(angle) * radius
		part(parent, name, Vector3.new(segment * 0.9, 1.2, 1.4), CFrame.new(x, y + 0.6, z) * CFrame.Angles(0, -angle - math.pi / 2, 0), RIM, Enum.Material.Cobblestone)
	end
end

-- Farol: poste de piedra con bola luminosa. Solo los del centro llevan luz para no saturar la escena.
local function lantern(parent: Instance, name: string, base: Vector3, withLight: boolean)
	part(parent, `{name}_Poste`, Vector3.new(0.8, 4, 0.8), CFrame.new(base + Vector3.new(0, 2, 0)), RIM, Enum.Material.Slate)
	local glow = part(parent, `{name}_Luz`, Vector3.new(1.6, 1.6, 1.6), CFrame.new(base + Vector3.new(0, 4.4, 0)), LANTERN_GLOW, Enum.Material.Neon)
	glow.Shape = Enum.PartType.Ball
	glow.CanCollide = false
	if withLight then
		local light = Instance.new("PointLight")
		light.Color = LANTERN_GLOW
		light.Range = 12
		light.Brightness = 0.8
		light.Parent = glow
	end
end

local function buildWave(parent: Instance)
	local y = ModeLayout.deckY()
	local origin = ModeLayout.waveOrigin()

	-- Isla: base de arena (la isla no tiene terreno, así que la pone esta función).
	disc(parent, "IslaBase", origin, ModeLayout.ISLAND_RADIUS, MapLayout.FLAT_HEIGHT - 0.3, BASE_SAND, Enum.Material.Sand)

	-- Lago: un disco de agua justo sobre el suelo plano, bajo las plataformas.
	local water = disc(parent, "Agua", origin, ModeLayout.WATER_RADIUS, MapLayout.FLAT_HEIGHT + 0.3, WATER, Enum.Material.Glass)
	water.Transparency = 0.35
	water.CanCollide = false

	for _, deck in ModeLayout.waveDecks() do
		local isCenter = deck.name == "Central"
		disc(parent, `Plataforma_{deck.name}`, deck.center, deck.radius, y, if isCenter then WOOD else ORANGE, Enum.Material.Wood)
		rim(parent, `Borde_{deck.name}`, deck.center, deck.radius, y)
		-- Cuatro faroles por plataforma, en diagonal para no tapar los puentes.
		for index = 0, 3 do
			local angle = math.pi / 4 + index * math.pi / 2
			local spot = deck.center + Vector2.new(math.cos(angle), math.sin(angle)) * (deck.radius - 1.5)
			lantern(parent, `Farol_{deck.name}_{index}`, Vector3.new(spot.X, y + 1.2, spot.Y), isCenter)
		end
	end
	-- Emblema del centro: disco claro encima de la madera, como en la referencia.
	local emblem = disc(parent, "Emblema", origin, 6, y + 0.45, MARBLE, Enum.Material.Marble)
	emblem.CanCollide = false
	for _, link in ModeLayout.waveBridges() do
		bridge(parent, link.from, link.to, link.width, y)
	end
end

local function buildBoss(parent: Instance)
	local y = ModeLayout.deckY()
	local lobby = ModeLayout.bossLobbyBox()
	local arena = ModeLayout.bossArena()
	-- Isla de la sala: base de piedra que cubre lobby, puente y arena.
	disc(parent, "IslaBase", ModeLayout.bossOrigin(), ModeLayout.ISLAND_RADIUS, MapLayout.FLAT_HEIGHT - 0.3, BASE_STONE, Enum.Material.Slate)

	part(parent, "SalaJefes_Lobby", Vector3.new(lobby.size.X, 0.6, lobby.size.Y), CFrame.new(lobby.center.X, y, lobby.center.Y), STONE, Enum.Material.Slate)
	disc(parent, "SalaJefes_Arena", arena.center, arena.radius, y, MARBLE, Enum.Material.Marble)

	-- Pilares alrededor de la arena: marcan el borde y dan referencia visual.
	for index = 0, 7 do
		local angle = index * math.pi / 4
		local x = arena.center.X + math.cos(angle) * (arena.radius - 2)
		local z = arena.center.Y + math.sin(angle) * (arena.radius - 2)
		part(parent, "Pilar", Vector3.new(2.4, 9, 2.4), CFrame.new(x, y + 4.5, z), MARBLE, Enum.Material.Marble)
	end

	local link = ModeLayout.bossBridge()
	bridge(parent, link.from, link.to, link.width, y)
end

-- Carpeta de las modalidades. Los servicios meten aquí sus pads.
function ModeArenaBuilder.folder(): Folder
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = workspace
	return folder
end

function ModeArenaBuilder.build()
	local previous = workspace:FindFirstChild(FOLDER_NAME)
	if previous ~= nil then
		previous:Destroy()
	end
	local folder = ModeArenaBuilder.folder()
	local waveModel = Instance.new("Model")
	waveModel.Name = "Oleadas"
	waveModel.Parent = folder
	buildWave(waveModel)

	local bossModel = Instance.new("Model")
	bossModel.Name = "Jefes"
	bossModel.Parent = folder
	buildBoss(bossModel)
end

return ModeArenaBuilder

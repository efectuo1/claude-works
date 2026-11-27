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

local function buildWave(parent: Instance)
	local y = ModeLayout.deckY()
	local origin = ModeLayout.waveOrigin()

	-- Lago: un disco de agua justo sobre el suelo plano, bajo las plataformas.
	local water = disc(parent, "Agua", origin, ModeLayout.WATER_RADIUS, MapLayout.FLAT_HEIGHT + 0.3, WATER, Enum.Material.Glass)
	water.Transparency = 0.35
	water.CanCollide = false

	for _, deck in ModeLayout.waveDecks() do
		disc(parent, `Plataforma_{deck.name}`, deck.center, deck.radius, y, WOOD, Enum.Material.Wood)
	end
	for _, link in ModeLayout.waveBridges() do
		bridge(parent, link.from, link.to, link.width, y)
	end
end

local function buildBoss(parent: Instance)
	local y = ModeLayout.deckY()
	local lobby = ModeLayout.bossLobbyBox()
	local arena = ModeLayout.bossArena()

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

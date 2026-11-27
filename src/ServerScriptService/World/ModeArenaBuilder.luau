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

-- Sala de jefes: solo lobby y base. Las peleas son islas aparte (buildArena).
local function buildHall(parent: Instance)
	local y = ModeLayout.deckY()
	local lobby = ModeLayout.bossLobbyBox()
	disc(parent, "IslaBase", ModeLayout.bossOrigin(), ModeLayout.ISLAND_RADIUS, MapLayout.FLAT_HEIGHT - 0.3, BASE_STONE, Enum.Material.Slate)
	part(parent, "SalaJefes_Lobby", Vector3.new(lobby.size.X, 0.6, lobby.size.Y), CFrame.new(lobby.center.X, y, lobby.center.Y), STONE, Enum.Material.Slate)
end

type Theme = {
	ground: Color3,
	groundMat: Enum.Material,
	floor: Color3,
	floorMat: Enum.Material,
	pillar: Color3?, -- si existe, se levantan pilares en el borde del disco
	decor: (Instance, Vector2, number, number) -> (),
}

-- Konoha destruida: suelo de piedra con cráter, pilares rotos, brasas y una puerta caída.
local function decorKonoha(parent: Instance, origin: Vector2, radius: number, y: number)
	local crater = disc(parent, "Cráter", origin, 9, y + 0.35, Color3.fromRGB(60, 45, 45), Enum.Material.Basalt)
	crater.CanCollide = false
	for index = 0, 5 do
		local angle = index * math.pi / 3
		local height = 4 + (index % 3) * 2.5
		local x = origin.X + math.cos(angle) * (radius - 5)
		local z = origin.Y + math.sin(angle) * (radius - 5)
		local pillar = part(parent, "Pilar roto", Vector3.new(2.4, height, 2.4), CFrame.new(x, y + height / 2, z) * CFrame.Angles(0, 0, math.rad(index % 2 == 0 and 6 or -9)), Color3.fromRGB(150, 140, 130), Enum.Material.Concrete)
		pillar.CanCollide = true
	end
	for index = 0, 5 do
		local angle = index * math.pi / 3 + math.pi / 6
		local spot = origin + Vector2.new(math.cos(angle), math.sin(angle)) * 14
		local ember = part(parent, "Brasa", Vector3.new(1.2, 1.2, 1.2), CFrame.new(spot.X, y + 0.8, spot.Y), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
		ember.Shape = Enum.PartType.Ball
		ember.CanCollide = false
	end
	-- Puerta caída al norte: dos postes y un dintel torcido en el suelo.
	local gate = origin + Vector2.new(0, -radius + 3)
	for _, side in { -1, 1 } do
		part(parent, "Puerta_poste", Vector3.new(3, 10, 3), CFrame.new(gate.X + side * 6, y + 5, gate.Y), Color3.fromRGB(150, 140, 130), Enum.Material.Concrete)
	end
	part(parent, "Puerta_dintel", Vector3.new(14, 2, 3), CFrame.new(gate.X, y + 10, gate.Y) * CFrame.Angles(0, 0, math.rad(8)), Color3.fromRGB(120, 110, 105), Enum.Material.Concrete)
end

-- Wano: suelo de madera roja, pilares laqueados, pagoda al norte y cerezos fuera del disco.
local function decorWano(parent: Instance, origin: Vector2, radius: number, y: number)
	local base = origin + Vector2.new(0, -radius + 8)
	local wood = Color3.fromRGB(200, 160, 110)
	local roof = Color3.fromRGB(70, 35, 35)
	for tier = 0, 2 do
		local size = 14 - tier * 4
		part(parent, `Pagoda_piso{tier}`, Vector3.new(size, 4, size), CFrame.new(base.X, y + 2 + tier * 4, base.Y), wood, Enum.Material.Wood)
		part(parent, `Pagoda_techo{tier}`, Vector3.new(size + 4, 1, size + 4), CFrame.new(base.X, y + 4.5 + tier * 4, base.Y), roof, Enum.Material.Wood)
	end
	for _, angle in { math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4 } do
		local spot = origin + Vector2.new(math.cos(angle), math.sin(angle)) * 42
		part(parent, "Cerezo_tronco", Vector3.new(1.6, 9, 1.6), CFrame.new(spot.X, y + 4.5, spot.Y), Color3.fromRGB(110, 70, 50), Enum.Material.Wood)
		local canopy = part(parent, "Cerezo_copa", Vector3.new(9, 9, 9), CFrame.new(spot.X, y + 11, spot.Y), Color3.fromRGB(255, 170, 200), Enum.Material.SmoothPlastic)
		canopy.Shape = Enum.PartType.Ball
	end
end

local THEMES: { [string]: Theme } = {
	konoha = {
		ground = Color3.fromRGB(120, 110, 110),
		groundMat = Enum.Material.Slate,
		floor = Color3.fromRGB(95, 90, 95),
		floorMat = Enum.Material.Slate,
		decor = decorKonoha,
	},
	wano = {
		ground = Color3.fromRGB(210, 180, 130),
		groundMat = Enum.Material.Sand,
		floor = Color3.fromRGB(170, 80, 50),
		floorMat = Enum.Material.Wood,
		pillar = Color3.fromRGB(190, 40, 40),
		decor = decorWano,
	},
}

-- Isla de combate de un escenario de jefe, con su ambientación.
local function buildArena(parent: Instance, arena: string)
	local theme = THEMES[arena] or THEMES.konoha
	local y = ModeLayout.deckY()
	local deck = ModeLayout.bossArenaDeck(arena)
	disc(parent, "IslaBase", deck.center, ModeLayout.ISLAND_RADIUS, MapLayout.FLAT_HEIGHT - 0.3, theme.ground, theme.groundMat)
	disc(parent, "Suelo", deck.center, deck.radius, y, theme.floor, theme.floorMat)

	if theme.pillar ~= nil then
		for index = 0, 7 do
			local angle = index * math.pi / 4
			local x = deck.center.X + math.cos(angle) * (deck.radius - 2)
			local z = deck.center.Y + math.sin(angle) * (deck.radius - 2)
			part(parent, "Pilar", Vector3.new(2.4, 9, 2.4), CFrame.new(x, y + 4.5, z), theme.pillar, Enum.Material.Wood)
		end
	end
	theme.decor(parent, deck.center, deck.radius, y)
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

	local hallModel = Instance.new("Model")
	hallModel.Name = "Jefes"
	hallModel.Parent = folder
	buildHall(hallModel)

	for _, arena in ModeLayout.ARENA_IDS do
		local model = Instance.new("Model")
		model.Name = `Escenario_{arena}`
		model.Parent = folder
		buildArena(model, arena)
	end
end

return ModeArenaBuilder

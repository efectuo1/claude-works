--!strict
--[[
	Hub de entrada. Disposición (vista desde la fuente, con el norte arriba = -Z):
	  Centro: plaza con fuente azul de cinco pisos, bancos, hoguera, diana, poste de flechas y bosque alrededor.
	  En cada punta de la isla central hay un punto de interés enorme sobre un círculo de arena:
	    Norte: gran ruleta.   Sur: tableros de clasificación.
	    Oeste: tres cabañas de modalidad (Oleadas, Jefes, próximamente).   Este: establo de la tienda.
	Las posiciones y escalas salen de MapLayout.landmarks(). Se rehace en cada arranque.
	Las piezas se construyen con HubPrimitives (base), HubStructures (cabañas y establo),
	HubLandmarks (ruleta y tableros) y HubNature (vegetación y mobiliario); aquí solo se disponen.
	Los carteles, el prompt de la tienda y los pads de entrada son los que usan los servicios.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local ModeLayout = require(ServerScriptService.World.ModeLayout)
local PadBuilder = require(ServerScriptService.World.PadBuilder)
local MapLayout = require(ServerScriptService.World.MapLayout)
local HubPrimitives = require(ServerScriptService.World.HubPrimitives)
local HubStructures = require(ServerScriptService.World.HubStructures)
local HubLandmarks = require(ServerScriptService.World.HubLandmarks)
local HubNature = require(ServerScriptService.World.HubNature)

local part = HubPrimitives.part
local soft = HubPrimitives.soft
local flatDisc = HubPrimitives.flatDisc
local emitter = HubPrimitives.emitter

local HubBuilder = {}

local HOUSE_SCALE = 1.35
local PAD_OFFSET = 9.5 -- distancia del pad a la cabaña, hacia la plaza
local SHOP_SCALE = 2.1

-- Cabañas de modalidad, de norte a sur. Cada una tiene un pad delante que lleva a su lobby.
local MODE_HOUSES = {
	{ id = "Oleadas", label = "OLEADAS", z = -13.5, color = Color3.fromRGB(90, 230, 110), destination = "wave" },
	{ id = "Jefes", label = "JEFES", z = 0, color = Color3.fromRGB(255, 90, 90), destination = "boss" },
	{ id = "Proximamente", label = "PRÓXIMAMENTE", z = 13.5, color = Color3.fromRGB(150, 150, 165), destination = nil },
}

local SAND = Color3.fromRGB(250, 220, 150)
local ROAD = Color3.fromRGB(196, 186, 170)
local STONE_COLORS = {
	Color3.fromRGB(200, 200, 215),
	Color3.fromRGB(255, 190, 120),
	Color3.fromRGB(170, 220, 255),
}
local FOUNTAIN_BLUE = Color3.fromRGB(60, 130, 235)
local FOUNTAIN_BLUE_DARK = Color3.fromRGB(35, 90, 200)
local WATER_COLOR = Color3.fromRGB(120, 220, 255)

-- Los tres círculos grandes de arena del borde de la plaza (grados) y su distancia al centro, en unidades locales.
local SAND_DEGREES = { 30, 90, 330 }
local SAND_DISTANCE = 36
local SAND_RADIUS = 9

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

-- Punto a `degrees` y `radius` del centro (en el plano XZ).
local function polar(center: Vector3, degrees: number, radius: number): Vector3
	local angle = math.rad(degrees)
	return center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

-- ¿Cae (x, z) dentro de uno de los círculos grandes de arena, con un margen?
local function nearSandCircle(x: number, z: number, margin: number): boolean
	for _, degrees in SAND_DEGREES do
		local angle = math.rad(degrees)
		local dx = x - math.cos(angle) * SAND_DISTANCE
		local dz = z - math.sin(angle) * SAND_DISTANCE
		if math.sqrt(dx * dx + dz * dz) < SAND_RADIUS + margin then
			return true
		end
	end
	return false
end

-- Los cuatro caminos salen por los ejes (0°, 90°, 180°, 270°): se dejan libres 12° a cada lado.
local function nearAxis(degrees: number): boolean
	local wrapped = degrees % 90
	return wrapped < 12 or wrapped > 78
end

-- Banco o diana que miran a `target`: el +Z local apunta hacia él.
local function facing(position: Vector3, target: Vector3): CFrame
	return CFrame.lookAt(position, position + (position - target))
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
	emitter(hub, center + Vector3.new(0, top + 1.4, 0), WATER_COLOR, 18, 5, 1.6, 22, 0.5)
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

-- ---------- Plaza central ----------

local function buildPlaza(hub: Folder, heightAt: HeightAt, groundY: number, rng: Random)
	local center = Vector3.new(0, groundY, 0)
	local plaza = Instance.new("Model")
	plaza.Name = "Plaza"
	plaza.Parent = hub

	-- Suelo de arena, círculo de piedra bajo la fuente y piedras grises en anillo.
	flatDisc(plaza, "Plaza", 30, 0.4, center + Vector3.new(0, 0.2, 0), SAND, Enum.Material.Sand)
	flatDisc(plaza, "PlazaCentro", 17, 0.25, center + Vector3.new(0, 0.45, 0), Color3.fromRGB(190, 200, 215), Enum.Material.Cobblestone)
	for index = 0, 13 do
		flatDisc(plaza, "PiedraAnillo", 1.8, 0.3, polar(center, index * 360 / 14 + 8, 26) + Vector3.new(0, 0.5, 0), Color3.fromRGB(150, 150, 160), Enum.Material.Slate)
	end
	for index = 0, 15 do
		flatDisc(plaza, "Piedra", 1.2, 0.4, polar(center, index * 22.5, 14) + Vector3.new(0, 0.6, 0), STONE_COLORS[(index % #STONE_COLORS) + 1], Enum.Material.Slate)
	end
	for index = 1, 9 do
		flatDisc(plaza, "Parterre", 2, 0.3, polar(center, index * 40, 11) + Vector3.new(0, 0.5, 0), Color3.fromRGB(255, 120, 180), Enum.Material.Grass)
	end
	fountain(plaza, center)

	-- Farolas y macizos de flores en dos anillos.
	for index = 0, 11 do
		HubNature.lamp(plaza, polar(center, index * 30 + 15, 22) + Vector3.new(0, 0.5, 0))
	end
	for index = 0, 5 do
		HubNature.flowerBed(plaza, polar(center, index * 60, 21) + Vector3.new(0, 0.5, 0), index)
	end

	-- Círculos grandes de arena con piedras y huellas en el borde de la plaza.
	for _, degrees in SAND_DEGREES do
		local spot = polar(center, degrees, SAND_DISTANCE) + Vector3.new(0, 0.3, 0)
		flatDisc(plaza, "ArenaGrande", SAND_RADIUS, 0.3, spot, SAND, Enum.Material.Sand)
		HubNature.pawRing(plaza, spot, 5.5, 4, rng)
		for stone = 0, 7 do
			local a = stone * math.pi / 4
			flatDisc(plaza, "PiedraArena", 1.1, 0.4, spot + Vector3.new(math.cos(a) * 8.2, 0.3, math.sin(a) * 8.2), Color3.fromRGB(150, 150, 160), Enum.Material.Slate)
		end
	end
	HubNature.pawRing(plaza, center, 24, 8, rng)

	-- Bancos mirando a la fuente.
	for _, degrees in { 45, 135, 225, 315 } do
		local spot = polar(center, degrees, 17.5) + Vector3.new(0, 0.4, 0)
		HubNature.bench(plaza, facing(spot, center))
	end

	-- Rincón de campamento: hoguera con dos bancos alrededor, a un lado del camino del oeste.
	local campfire = polar(center, 135, 34)
	campfire = Vector3.new(campfire.X, heightAt(campfire.X, campfire.Z), campfire.Z)
	HubNature.campfire(plaza, campfire)
	for _, offset in { 70, 290 } do
		local seat = campfire + Vector3.new(math.cos(math.rad(135 + offset)) * 5.2, 0, math.sin(math.rad(135 + offset)) * 5.2)
		HubNature.bench(plaza, facing(seat, campfire))
	end

	-- Diana de tiro con arco, de cara a la fuente.
	local targetSpot = polar(center, 215, 34)
	HubNature.archery(plaza, facing(Vector3.new(targetSpot.X, heightAt(targetSpot.X, targetSpot.Z), targetSpot.Z), center))

	-- Poste con una flecha hacia cada punto de interés.
	local postSpot = polar(center, 60, 31)
	postSpot = Vector3.new(postSpot.X, heightAt(postSpot.X, postSpot.Z), postSpot.Z)
	local labels: { [string]: { text: string, color: Color3 } } = {
		modalidades = { text = "MODOS", color = Color3.fromRGB(80, 200, 100) },
		tienda = { text = "TIENDA", color = Color3.fromRGB(255, 140, 40) },
		ruleta = { text = "RULETA", color = Color3.fromRGB(240, 80, 170) },
		tableros = { text = "TABLEROS", color = Color3.fromRGB(70, 130, 255) },
	}
	local arrows: { HubNature.Arrow } = {}
	for _, landmark in MapLayout.landmarks() do
		local info = labels[landmark.id]
		if info ~= nil then
			local dx = landmark.center.X / MapLayout.HUB_SCALE - postSpot.X
			local dz = landmark.center.Y / MapLayout.HUB_SCALE - postSpot.Z
			table.insert(arrows, { text = info.text, degrees = math.deg(math.atan2(-dz, dx)), color = info.color })
		end
	end
	HubNature.signpost(plaza, postSpot, arrows)

	-- Vallas de madera en dos arcos del borde, dejando libres los caminos.
	HubNature.fenceArc(plaza, center + Vector3.new(0, 0.4, 0), 28.5, 100, 170)
	HubNature.fenceArc(plaza, center + Vector3.new(0, 0.4, 0), 28.5, 190, 260)

	-- Estrellas de colores en el suelo y racimos de gemas, como en la referencia.
	HubNature.starTrail(plaza, center + Vector3.new(27, 0.4, -12), center + Vector3.new(27, 0.4, 12), 9, 5, rng)
	HubNature.gemCluster(plaza, center + Vector3.new(-30, 0.4, 18), rng, 12)
	HubNature.gemCluster(plaza, center + Vector3.new(26, 0.4, -22), rng, 12)

	-- Bosque: árboles redondos y pinos en un anillo (sin tapar caminos ni arena), setos, tocones y setas.
	for index = 0, 23 do
		local degrees = index * 15 + rng:NextNumber(-4, 4)
		local radius = rng:NextNumber(39, 47)
		local spot = polar(center, degrees, radius)
		if not nearAxis(degrees) and not nearSandCircle(spot.X, spot.Z, 2) then
			local base = Vector3.new(spot.X, heightAt(spot.X, spot.Z), spot.Z)
			if index % 3 == 1 then
				HubNature.pine(plaza, base, rng)
			else
				HubNature.tree(plaza, base, rng)
			end
		end
	end
	for _ = 1, 18 do
		local degrees = rng:NextNumber(0, 360)
		local spot = polar(center, degrees, rng:NextNumber(35.5, 38))
		if not nearAxis(degrees) and not nearSandCircle(spot.X, spot.Z, 1) then
			HubNature.bush(plaza, Vector3.new(spot.X, heightAt(spot.X, spot.Z), spot.Z), rng)
		end
	end
	for index = 1, 24 do
		local degrees = rng:NextNumber(0, 360)
		local spot = polar(center, degrees, rng:NextNumber(32, 41))
		if not nearAxis(degrees) and not nearSandCircle(spot.X, spot.Z, 2) then
			local base = Vector3.new(spot.X, heightAt(spot.X, spot.Z), spot.Z)
			if index % 3 == 0 then
				HubNature.stump(plaza, base)
			else
				HubNature.mushroom(plaza, base, rng:NextNumber(0.9, 1.5))
			end
		end
	end
	for _ = 0, 9 do
		local angle = math.rad(rng:NextNumber(0, 360))
		local radius = rng:NextNumber(8, 30)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		emitter(plaza, Vector3.new(x, heightAt(x, z) + 3, z), Color3.fromRGB(240, 255, 120), 2, 1, 4, 180)
	end

	scaleAndPlace(plaza, groundY, MapLayout.HUB_SCALE, CFrame.new(center))
end

-- ---------- Puntos de interés ----------
-- Cada uno se construye en tamaño base alrededor del origen local, con la puerta o la cara hacia +X (la plaza),
-- y luego se agranda y se coloca en su punta de la isla (ver scaleAndPlace).

-- Piedras grandes en el borde del círculo de arena.
local function stoneRing(model: Model, radius: number, groundY: number, rng: Random)
	local count = 20
	for index = 0, count - 1 do
		local angle = index * 2 * math.pi / count + rng:NextNumber(-0.05, 0.05)
		local position = Vector3.new(math.cos(angle) * radius, groundY + 0.5, math.sin(angle) * radius)
		flatDisc(model, "PiedraBorde", rng:NextNumber(1, 1.6), 0.5, position, STONE_COLORS[index % #STONE_COLORS + 1], Enum.Material.Slate)
	end
end

-- Tres cabañas de modalidad en fila, con un pad delante de cada una que lleva a su lobby.
local function buildModes(model: Model, groundY: number, rng: Random)
	for _, mode in MODE_HOUSES do
		HubStructures.cabin(model, `Casa{mode.id}`, Vector3.new(0, groundY, mode.z), Vector3.new(-1, 0, 0), HOUSE_SCALE, HubStructures.CABIN, mode.label)
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
	-- Calle de adoquín delante de los pads, con farolas en los extremos y pinos detrás de las cabañas.
	local street = PAD_OFFSET + 5
	part(model, "Calle", Vector3.new(4, 0.3, 42), CFrame.new(Vector3.new(street, groundY + 0.35, 0)), ROAD, Enum.Material.Cobblestone)
	for _, z in { -20, 20 } do
		HubNature.lamp(model, Vector3.new(street + 2, groundY, z))
	end
	for _, z in { -18, -6, 6, 18 } do
		HubNature.pine(model, Vector3.new(-13, groundY, z), rng)
	end
end

-- Tienda: establo rojo con cartel y un prompt que abre la ventana de tienda (Bootstrap lo conecta).
local function buildShop(model: Model, groundY: number, rng: Random)
	local door = HubStructures.cabin(model, "Tienda", Vector3.new(0, groundY, 0), Vector3.new(-1, 0, 0), SHOP_SCALE, HubStructures.BARN, "TIENDA")
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
	-- Adoquín desde la puerta hacia la plaza y mercancía junto a la fachada.
	part(model, "CaminoTienda", Vector3.new(14, 0.3, 4), CFrame.new(door + Vector3.new(7, 0.35, 0)), ROAD, Enum.Material.Cobblestone)
	for _, side in { 1, -1 } do
		HubNature.barrel(model, door + Vector3.new(2.4, 0, side * 6.4))
		HubNature.crate(model, door + Vector3.new(2.2, 0, side * 8.8), rng:NextNumber(-0.3, 0.3))
		HubNature.crate(model, door + Vector3.new(2.2, 2, side * 8.8), rng:NextNumber(-0.3, 0.3))
		HubNature.hayBale(model, door + Vector3.new(3.4, 0, side * 12), math.rad(90))
	end
	HubNature.lamp(model, door + Vector3.new(9, 0, 0))
end

-- Ruleta con su bastidor, y dos bancos delante para mirarla.
local function buildWheel(model: Model, groundY: number)
	HubLandmarks.wheel(model, groundY)
	for _, side in { 1, -1 } do
		local seat = Vector3.new(15, groundY + 0.3, side * 7)
		HubNature.bench(model, CFrame.lookAt(seat, seat + Vector3.new(1, 0, 0)))
	end
end

-- Tableros de clasificación, con gemas detrás, y bancos delante.
local function buildBoards(model: Model, groundY: number, rng: Random)
	HubLandmarks.boards(model, groundY, rng)
	for _, side in { 1, -1 } do
		local seat = Vector3.new(11, groundY + 0.3, side * 7)
		HubNature.bench(model, CFrame.lookAt(seat, seat + Vector3.new(1, 0, 0)))
	end
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

	buildPlaza(hub, heightAt, groundY, rng)

	-- ---------- Puntos de interés, uno en cada punta ----------
	local builders: { [string]: (Model) -> () } = {
		modes = function(model)
			buildModes(model, groundY, rng)
		end,
		shop = function(model)
			buildShop(model, groundY, rng)
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

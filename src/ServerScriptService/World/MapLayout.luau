--!strict
--[[
	Plano del mapa como datos puros: islas, altura del terreno, puntos de spawn, puentes, caminos
	y franjas libres de decoración. No toca Instances, así que se prueba sin Studio.

	Disposición (XZ, centro = 0,0):
	  Isla grande (0, 0), radio 380: el mundo. Plaza de inicio con fuente en el centro; en cada punta de la
	    isla central hay un punto de interés grande sobre un círculo de arena: casas de modalidad al oeste,
	    tienda al este, ruleta al norte y tableros de clasificación al sur. El borde baja en escalones de hierba.
	  Cuatro islas satélite en las esquinas (±370, ±370), cada una unida a la grande por un puente de madera:
	    Campo de Lobos (NE), Claro de Espíritus (NO), Cueva del Bruto (SE) y Aldea de Misiones (SO).
	Las modalidades (oleadas y jefes) están en otra isla, fuera de este mapa (ver ModeLayout).
]]

export type Kind = "hub" | "shop" | "modes" | "bosses" | "wheel" | "boards"
export type Region = { id: string, kind: Kind, center: Vector2, radius: number }
export type Corridor = { from: Vector2, to: Vector2, halfWidth: number }
export type Surface = "Rock" | "Sand" | "Grass" | "Stone"
export type Landmark = { id: string, kind: Kind, center: Vector2, radius: number, scale: number }
export type Island = { id: string, name: string, center: Vector2, radius: number, rim: number }
export type Bridge = { id: string, name: string, from: Vector2, to: Vector2, halfWidth: number }

local MapLayout = {}

MapLayout.HALF_SIZE = 520 -- el mapa va de -520 a 520 en X y en Z (1040 studs)
MapLayout.FLAT_HEIGHT = 2
MapLayout.BLEND = 30 -- studs de transición desde una zona plana hasta el relieve
MapLayout.EDGE_WIDTH = 24 -- franja de roca en el borde del mapa

-- Mar: el agua queda 10 studs por debajo de la meseta, así las terrazas del borde caben entre medias.
MapLayout.SEA_LEVEL = -8
MapLayout.SEA_FLOOR = -22 -- altura del fondo del mar

-- Isla grande: meseta circular. Su borde baja en dos terrazas de hierba (4 studs cada una) y un talud de roca.
MapLayout.ISLAND_RADIUS = 380
MapLayout.RIM_WIDTH = 60 -- anchura del borde con terrazas, desde la meseta hasta el mar

-- Escala del hub respecto al tamaño base de HubBuilder (se agranda con Model:ScaleTo).
MapLayout.HUB_SCALE = 2.4

local SATELLITE_RADIUS = 66
local SATELLITE_RIM = 18
local PLATEAU_REACH = 318 -- hasta dónde llega un puente por el lado de la isla grande (meseta: 380 - 60 = 320)
local ROAD_START = 118 -- los caminos arrancan donde acaba la zona plana del hub

local ISLANDS: { Island } = {
	{ id = "principal", name = "Isla principal", center = Vector2.zero, radius = MapLayout.ISLAND_RADIUS, rim = MapLayout.RIM_WIDTH },
	{ id = "lobos", name = "CAMPO DE LOBOS", center = Vector2.new(370, -370), radius = SATELLITE_RADIUS, rim = SATELLITE_RIM },
	{ id = "espiritus", name = "CLARO DE ESPÍRITUS", center = Vector2.new(-370, -370), radius = SATELLITE_RADIUS, rim = SATELLITE_RIM },
	{ id = "bruto", name = "CUEVA DEL BRUTO", center = Vector2.new(370, 370), radius = SATELLITE_RADIUS, rim = SATELLITE_RIM },
	{ id = "aldea", name = "ALDEA DE MISIONES", center = Vector2.new(-370, 370), radius = SATELLITE_RADIUS, rim = SATELLITE_RIM },
}

-- Un puente por satélite: sale de la meseta de la isla grande y llega a la meseta del satélite.
-- No es terreno: reserva el paso y WorldBuilder lo construye con piezas de madera.
local BRIDGE_HALF_WIDTH = 4
local BRIDGES: { Bridge } = {}
-- Los caminos de tierra unen la plaza con cada puente y cada puente con el centro de su isla.
local ROADS: { Corridor } = {}
for _, island in ISLANDS do
	if island.id ~= "principal" then
		local dir = island.center.Unit
		local from = dir * PLATEAU_REACH
		local to = island.center - dir * (island.radius - island.rim - 2)
		table.insert(BRIDGES, { id = island.id, name = island.name, from = from, to = to, halfWidth = BRIDGE_HALF_WIDTH })
		table.insert(ROADS, { from = dir * ROAD_START, to = from, halfWidth = BRIDGE_HALF_WIDTH })
		table.insert(ROADS, { from = to, to = island.center, halfWidth = BRIDGE_HALF_WIDTH })
	end
end

-- Puntos de interés del hub, uno en cada punta de la isla central. Cada uno se construye en tamaño base y se
-- agranda `scale` veces; `radius` es su círculo de arena plano (en studs del mundo). Miran a la plaza.
local LANDMARK_DISTANCE = 205
local LANDMARKS: { Landmark } = {
	{ id = "modalidades", kind = "modes", center = Vector2.new(-LANDMARK_DISTANCE, 0), radius = 95, scale = 5 },
	{ id = "tienda", kind = "shop", center = Vector2.new(LANDMARK_DISTANCE, 0), radius = 90, scale = 5 },
	{ id = "ruleta", kind = "wheel", center = Vector2.new(0, -LANDMARK_DISTANCE), radius = 75, scale = 4 },
	{ id = "tableros", kind = "boards", center = Vector2.new(0, LANDMARK_DISTANCE), radius = 80, scale = 4.5 },
}

-- Zonas planas reservadas: la plaza (grande, se agranda con HUB_SCALE) y el círculo de cada punto de interés.
local REGIONS: { Region } = {
	{ id = "hub", kind = "hub", center = Vector2.zero, radius = 115 },
}
for _, landmark in LANDMARKS do
	table.insert(REGIONS, { id = landmark.id, kind = landmark.kind, center = landmark.center, radius = landmark.radius })
	-- Camino de adoquín desde el borde de la plaza (radio 72) hasta el círculo de arena del punto de interés.
	local dir = landmark.center.Unit
	table.insert(ROADS, { from = dir * 74, to = landmark.center - dir * (landmark.radius * 0.75), halfWidth = 6 })
end

local CORRIDORS: { Corridor } = {}

-- Dónde aparecen los jugadores al empezar y al volver al hub: al lado de la fuente, por la derecha.
MapLayout.HUB_SPAWN = Vector2.new(30, 0)

-- Nombres = spawnPointName de Zones.luau. Cada grupo de mobs vive en su isla satélite, lejos del acantilado.
local SPAWN_POINTS: { [string]: Vector2 } = {
	Wolf_1 = Vector2.new(350, -390),
	Wolf_2 = Vector2.new(392, -352),
	Wolf_3 = Vector2.new(365, -345),
	Sprite_1 = Vector2.new(-394, -376),
	Sprite_2 = Vector2.new(-348, -362),
	Brute_1 = Vector2.new(375, 375),
}

local function distanceToSegment(p: Vector2, a: Vector2, b: Vector2): number
	local ab = b - a
	local lengthSq = ab:Dot(ab)
	local t = if lengthSq == 0 then 0 else math.clamp((p - a):Dot(ab) / lengthSq, 0, 1)
	return (p - (a + ab * t)).Magnitude
end

function MapLayout.regions(): { Region }
	return REGIONS
end

function MapLayout.islands(): { Island }
	return ISLANDS
end

function MapLayout.landmarks(): { Landmark }
	return LANDMARKS
end

function MapLayout.bridges(): { Bridge }
	return BRIDGES
end

function MapLayout.roads(): { Corridor }
	return ROADS
end

-- True si el punto cae en la meseta de alguna isla (no en las terrazas ni en el mar), con margen.
function MapLayout.onLand(p: Vector2, margin: number): boolean
	for _, island in ISLANDS do
		if (p - island.center).Magnitude <= island.radius - island.rim - margin then
			return true
		end
	end
	return false
end

function MapLayout.region(id: string): Region?
	for _, region in REGIONS do
		if region.id == id then
			return region
		end
	end
	return nil
end

function MapLayout.spawnPoints(): { [string]: Vector2 }
	return SPAWN_POINTS
end

-- Escalones del borde de una isla, medidos hacia dentro desde su orilla (d = radio - distancia al centro):
--   0 .. s1   talud de roca desde el fondo del mar hasta la terraza baja
--   s1 .. s2  terraza baja (8 studs bajo la meseta)
--   s2 .. s3  terraza alta (4 studs bajo la meseta), unida a la baja por un escalón de w studs
--   s3 + w .. meseta
local function bands(rim: number): (number, number, number, number)
	return rim * 0.25, rim * 0.5, rim * 0.75, math.max(1, rim * 0.05)
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Altura del borde de una isla a d studs de su orilla. `land` es la altura de la meseta en ese punto.
local function rimHeight(d: number, rim: number, land: number): number
	local s1, s2, s3, w = bands(rim)
	local high = MapLayout.FLAT_HEIGHT - 4
	local low = MapLayout.FLAT_HEIGHT - 8
	if d <= 0 then
		return MapLayout.SEA_FLOOR
	elseif d < s1 then
		return MapLayout.SEA_FLOOR + (low - MapLayout.SEA_FLOOR) * smooth(d / s1)
	elseif d < s2 then
		return low
	elseif d < s2 + w then
		return low + (high - low) * smooth((d - s2) / w)
	elseif d < s3 then
		return high
	elseif d < s3 + w then
		return high + (land - high) * smooth((d - s3) / w)
	end
	return land
end

-- Altura del terreno en (x, z). Relieve suave de ruido sobre la meseta, el borde en terrazas,
-- y aplanado por cada zona y cada camino. Dentro de una zona la altura queda en FLAT_HEIGHT,
-- y la transición es continua.
function MapLayout.height(x: number, z: number): number
	local broad = math.noise(x / 140, z / 140, 3.7)
	local detail = math.noise(x / 30, z / 30, 9.1) * 0.5
	local p = Vector2.new(x, z)
	local land = MapLayout.FLAT_HEIGHT + 0.6 + broad * 0.6 + detail * 0.4
	local h = MapLayout.SEA_FLOOR
	for _, island in ISLANDS do
		local d = island.radius - (p - island.center).Magnitude
		if d > 0 then
			h = math.max(h, rimHeight(d, island.rim, land))
		end
	end

	for _, region in REGIONS do
		local d = (p - region.center).Magnitude - region.radius
		local t = math.clamp(d / MapLayout.BLEND, 0, 1)
		h = MapLayout.FLAT_HEIGHT + (h - MapLayout.FLAT_HEIGHT) * t
	end
	for _, corridor in CORRIDORS do
		local d = distanceToSegment(p, corridor.from, corridor.to) - corridor.halfWidth
		local t = math.clamp(d / MapLayout.BLEND, 0, 1)
		h = MapLayout.FLAT_HEIGHT + (h - MapLayout.FLAT_HEIGHT) * t
	end
	return h
end

-- True si el punto está fuera de zonas, puentes y caminos (con margen) y dentro del área jugable.
function MapLayout.isClear(p: Vector2, margin: number): boolean
	local limit = MapLayout.HALF_SIZE - MapLayout.EDGE_WIDTH - margin
	if math.abs(p.X) > limit or math.abs(p.Y) > limit then
		return false
	end
	-- Fuera de las mesetas (en las terrazas o en el mar) no se pone nada de decoración ni de mobs.
	if not MapLayout.onLand(p, margin) then
		return false
	end
	for _, bridge in BRIDGES do
		if distanceToSegment(p, bridge.from, bridge.to) < bridge.halfWidth + margin then
			return false
		end
	end
	for _, road in ROADS do
		if distanceToSegment(p, road.from, road.to) < road.halfWidth + margin then
			return false
		end
	end
	for _, region in REGIONS do
		if (p - region.center).Magnitude < region.radius + margin then
			return false
		end
	end
	for _, corridor in CORRIDORS do
		if distanceToSegment(p, corridor.from, corridor.to) < corridor.halfWidth + margin then
			return false
		end
	end
	return true
end

-- Material lógico de una columna. WorldBuilder lo traduce a Enum.Material.
-- Las terrazas son de hierba; el talud y los escalones entre terrazas son de roca lila.
function MapLayout.surfaceAt(x: number, z: number, h: number): Surface
	if math.max(math.abs(x), math.abs(z)) > MapLayout.HALF_SIZE - MapLayout.EDGE_WIDTH or h > 20 then
		return "Rock"
	end
	local p = Vector2.new(x, z)
	for _, island in ISLANDS do
		local d = island.radius - (p - island.center).Magnitude
		if d >= 0 then
			local s1, s2, s3, w = bands(island.rim)
			if d < s1 + 1 then
				return "Rock"
			elseif d < s2 - 1 then
				return "Grass"
			elseif d < s2 + w + 1 then
				return "Rock"
			elseif d < s3 - 1 then
				return "Grass"
			elseif d < s3 + w + 1 then
				return "Rock"
			end
		end
	end
	-- Los caminos van primero: así el de piedra no se corta con el anillo de arena de la plaza.
	for _, corridor in CORRIDORS do
		if distanceToSegment(p, corridor.from, corridor.to) <= corridor.halfWidth then
			return "Stone"
		end
	end
	for _, region in REGIONS do
		local d = (p - region.center).Magnitude
		if region.kind == "hub" then
			local ring = 36 * MapLayout.HUB_SCALE
			if math.abs(d - ring) < 3 * MapLayout.HUB_SCALE then
				return "Sand"
			end
		elseif region.kind == "bosses" then
			if d <= region.radius then
				return "Stone"
			end
		elseif d <= region.radius then
			return "Sand"
		end
	end
	return "Grass"
end

return table.freeze(MapLayout)

--!strict
--[[
	Plano del mapa como datos puros: zonas, altura del terreno, puntos de spawn, caminos
	y franjas libres de decoración. No toca Instances, así que se prueba sin Studio.

	Disposición (XZ, centro = 0,0):
	  Centro (0, 0):    plaza de inicio con fuente, casas de modalidad al oeste, tienda al este.
	  Campos de mobs:   anillo entre el centro y el borde del mapa.
	Las modalidades (oleadas y jefes) están en una isla aparte, fuera de este mapa (ver ModeLayout).
]]

export type Kind = "hub" | "shop" | "modes" | "bosses"
export type Region = { id: string, kind: Kind, center: Vector2, radius: number }
export type Corridor = { from: Vector2, to: Vector2, halfWidth: number }
export type Surface = "Rock" | "Sand" | "Grass" | "Stone"

local MapLayout = {}

MapLayout.HALF_SIZE = 480 -- el mapa va de -480 a 480 en X y en Z (960 studs)
MapLayout.FLAT_HEIGHT = 2
MapLayout.BLEND = 30 -- studs de transición desde una zona plana hasta el relieve
MapLayout.EDGE_WIDTH = 24 -- franja de roca en el borde del mapa

-- Isla: meseta circular rodeada de mar. Dentro, la tierra tiene poco relieve; el borde cae en
-- un acantilado de roca hasta el fondo del mar. Fuera de la isla no hay tierra, solo agua.
MapLayout.ISLAND_RADIUS = 380
MapLayout.RIM_WIDTH = 60 -- anchura del acantilado de roca que baja desde la meseta
MapLayout.SEA_FLOOR = -10 -- altura del fondo del mar
MapLayout.SEA_LEVEL = 0 -- nivel del agua

-- Solo el hub ocupa el terreno principal. Las modalidades viven en su propia isla (ModeLayout),
-- lejos del mapa, así que no necesitan zona aquí.
local REGIONS: { Region } = {
	{ id = "hub", kind = "hub", center = Vector2.new(0, 0), radius = 40 },
}

local CORRIDORS: { Corridor } = {}

-- Dónde aparecen los jugadores al empezar y al volver al hub: al lado de la fuente, por la derecha.
MapLayout.HUB_SPAWN = Vector2.new(12, 0)

-- Nombres = spawnPointName de Zones.luau. Todos quedan en los campos, fuera de zonas y caminos.
local SPAWN_POINTS: { [string]: Vector2 } = {
	Wolf_1 = Vector2.new(-70, 120),
	Wolf_2 = Vector2.new(-110, -110),
	Wolf_3 = Vector2.new(-30, -150),
	Sprite_1 = Vector2.new(90, 130),
	Sprite_2 = Vector2.new(150, -120),
	Brute_1 = Vector2.new(100, -165),
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

-- Altura del terreno en (x, z). Relieve de ruido, aplanado por cada zona y cada camino.
-- Se aplican en orden: dentro de cualquiera de ellos la altura queda en FLAT_HEIGHT,
-- y la transición es continua.
-- Cuánto de la isla es tierra en un punto: 1 en la meseta, 0 en el mar, con transición suave en el borde.
local function landMask(r: number): number
	local t = math.clamp((MapLayout.ISLAND_RADIUS - r) / MapLayout.RIM_WIDTH, 0, 1)
	return t * t * (3 - 2 * t)
end

function MapLayout.height(x: number, z: number): number
	local broad = math.noise(x / 140, z / 140, 3.7)
	local detail = math.noise(x / 30, z / 30, 9.1) * 0.5
	local p = Vector2.new(x, z)
	local land = MapLayout.FLAT_HEIGHT + 2 + broad * 7 + detail * 1.5
	local h = MapLayout.SEA_FLOOR + (land - MapLayout.SEA_FLOOR) * landMask(p.Magnitude)

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

-- True si el punto está fuera de zonas y caminos (con margen) y dentro del área jugable.
function MapLayout.isClear(p: Vector2, margin: number): boolean
	local limit = MapLayout.HALF_SIZE - MapLayout.EDGE_WIDTH - margin
	if math.abs(p.X) > limit or math.abs(p.Y) > limit then
		return false
	end
	-- Fuera de la meseta (en el acantilado o en el mar) no se pone nada de decoración ni de mobs.
	if p.Magnitude > MapLayout.ISLAND_RADIUS - MapLayout.RIM_WIDTH / 2 - margin then
		return false
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
function MapLayout.surfaceAt(x: number, z: number, h: number): Surface
	if math.max(math.abs(x), math.abs(z)) > MapLayout.HALF_SIZE - MapLayout.EDGE_WIDTH or h > 20 then
		return "Rock"
	end
	local p = Vector2.new(x, z)
	local r = p.Magnitude
	-- Playa en el borde de la isla y acantilado de roca lila debajo de la meseta.
	if r > MapLayout.ISLAND_RADIUS - 14 then
		return "Sand"
	end
	if r > MapLayout.ISLAND_RADIUS - MapLayout.RIM_WIDTH then
		return "Rock"
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
			if math.abs(d - 36) < 3 then
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

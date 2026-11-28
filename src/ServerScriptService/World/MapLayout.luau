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
export type Island = { id: string, center: Vector2, radius: number, rim: number }

local MapLayout = {}

MapLayout.HALF_SIZE = 400 -- el mapa va de -400 a 400 en X y en Z (800 studs)
MapLayout.FLAT_HEIGHT = 2
MapLayout.BLEND = 30 -- studs de transición desde una zona plana hasta el relieve
MapLayout.EDGE_WIDTH = 24 -- franja de roca en el borde del mapa

-- Islas: mesetas circulares rodeadas de mar. Dentro, la tierra es casi plana; el borde cae en
-- un acantilado de roca hasta el fondo del mar. Fuera de las islas no hay tierra, solo agua.
MapLayout.ISLAND_RADIUS = 100 -- isla del hub
MapLayout.RIM_WIDTH = 24 -- anchura del acantilado de roca que baja desde la meseta
MapLayout.SEA_FLOOR = -10 -- altura del fondo del mar
MapLayout.SEA_LEVEL = 0 -- nivel del agua

local ISLANDS: { Island } = {
	{ id = "hub", center = Vector2.new(0, 0), radius = 100, rim = 24 },
	{ id = "campo", center = Vector2.new(230, 0), radius = 90, rim = 22 },
}

-- Puente de madera entre las dos islas. No es terreno: solo reserva el paso para que no haya decoración encima.
MapLayout.BRIDGE = { from = Vector2.new(70, 0), to = Vector2.new(165, 0), halfWidth = 4 }

-- Solo el hub tiene zona plana reservada. Las modalidades viven en su propia isla (ModeLayout),
-- lejos del mapa, así que no necesitan zona aquí.
local REGIONS: { Region } = {
	{ id = "hub", kind = "hub", center = Vector2.new(0, 0), radius = 40 },
}

local CORRIDORS: { Corridor } = {}

-- Dónde aparecen los jugadores al empezar y al volver al hub: al lado de la fuente, por la derecha.
MapLayout.HUB_SPAWN = Vector2.new(14, 0)

-- Nombres = spawnPointName de Zones.luau. Todos quedan en la isla del campo (centro 230, 0), lejos del acantilado.
local SPAWN_POINTS: { [string]: Vector2 } = {
	Wolf_1 = Vector2.new(195, -30),
	Wolf_2 = Vector2.new(265, -25),
	Wolf_3 = Vector2.new(200, 30),
	Sprite_1 = Vector2.new(255, 35),
	Sprite_2 = Vector2.new(232, -45),
	Brute_1 = Vector2.new(270, 10),
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

-- True si el punto cae en la meseta de alguna isla (no en el acantilado ni en el mar), con margen.
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

-- Altura del terreno en (x, z). Relieve de ruido, aplanado por cada zona y cada camino.
-- Se aplican en orden: dentro de cualquiera de ellos la altura queda en FLAT_HEIGHT,
-- y la transición es continua.
-- Cuánto de una isla es tierra a distancia r de su centro: 1 en la meseta, 0 en el mar, con transición suave en el borde.
local function landMask(r: number, radius: number, rim: number): number
	local t = math.clamp((radius - r) / rim, 0, 1)
	return t * t * (3 - 2 * t)
end

function MapLayout.height(x: number, z: number): number
	local broad = math.noise(x / 140, z / 140, 3.7)
	local detail = math.noise(x / 30, z / 30, 9.1) * 0.5
	local p = Vector2.new(x, z)
	local land = MapLayout.FLAT_HEIGHT + 1.2 + broad * 0.8 + detail * 0.3
	local mask = 0
	for _, island in ISLANDS do
		mask = math.max(mask, landMask((p - island.center).Magnitude, island.radius, island.rim))
	end
	local h = MapLayout.SEA_FLOOR + (land - MapLayout.SEA_FLOOR) * mask

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
	-- Fuera de las mesetas (en el acantilado o en el mar) no se pone nada de decoración ni de mobs.
	if not MapLayout.onLand(p, margin) then
		return false
	end
	if distanceToSegment(p, MapLayout.BRIDGE.from, MapLayout.BRIDGE.to) < MapLayout.BRIDGE.halfWidth + margin then
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
	-- Playa en el borde de cada isla y acantilado de roca lila debajo de la meseta.
	for _, island in ISLANDS do
		local r = (p - island.center).Magnitude
		if r <= island.radius then
			if r > island.radius - 14 then
				return "Sand"
			end
			if r > island.radius - island.rim then
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

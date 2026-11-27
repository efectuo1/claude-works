--!strict
--[[
	Plano del mapa como datos puros: zonas, altura del terreno, puntos de spawn, caminos
	y franjas libres de decoración. No toca Instances, así que se prueba sin Studio.

	Disposición (XZ, centro = 0,0):
	  Oeste  (-190, 0): arena de oleadas (plataformas y puentes sobre agua).
	  Centro (0, 0):    plaza de inicio con fuente y las cuatro cabañas de modalidades al norte.
	  Este   (190, 0):  tienda.
	  Sur    (0, 190):  sala de jefes (lobby, puente y arena).
	  Campos de mobs:   anillo entre el centro y el borde del mapa.
]]

export type Kind = "hub" | "shop" | "modes" | "bosses"
export type Region = { id: string, kind: Kind, center: Vector2, radius: number }
export type Corridor = { from: Vector2, to: Vector2, halfWidth: number }
export type Surface = "Rock" | "Sand" | "Grass" | "Stone"

local MapLayout = {}

MapLayout.HALF_SIZE = 320 -- el mapa va de -320 a 320 en X y en Z (640 studs)
MapLayout.FLAT_HEIGHT = 2
MapLayout.BLEND = 30 -- studs de transición desde una zona plana hasta el relieve
MapLayout.EDGE_WIDTH = 24 -- franja de roca en el borde del mapa

local REGIONS: { Region } = {
	{ id = "hub", kind = "hub", center = Vector2.new(0, 0), radius = 40 },
	{ id = "shop", kind = "shop", center = Vector2.new(190, 0), radius = 30 },
	-- La arena de oleadas ocupa 64 studs desde su centro (satélites incluidos): la zona plana la rodea con margen.
	{ id = "modes", kind = "modes", center = Vector2.new(-190, 0), radius = 70 },
	-- La sala de jefes cubre desde el lobby (norte) hasta el fondo de la arena (sur).
	{ id = "bosses", kind = "bosses", center = Vector2.new(0, 190), radius = 62 },
}

local CORRIDORS: { Corridor } = {
	{ from = Vector2.new(0, 0), to = Vector2.new(190, 0), halfWidth = 9 },
	{ from = Vector2.new(0, 0), to = Vector2.new(-190, 0), halfWidth = 9 },
	{ from = Vector2.new(0, 0), to = Vector2.new(0, 190), halfWidth = 9 },
}

-- Dónde aparecen los jugadores al empezar y al volver al hub: al lado de la fuente, por la derecha.
MapLayout.HUB_SPAWN = Vector2.new(12, 0) -- al lado de la fuente, por la derecha

-- Nombres = spawnPointName de Zones.luau. Todos quedan en los campos, fuera de zonas y caminos.
local SPAWN_POINTS: { [string]: Vector2 } = {
	Wolf_1 = Vector2.new(-70, 120),
	Wolf_2 = Vector2.new(-110, -110),
	Wolf_3 = Vector2.new(-30, -150),
	Sprite_1 = Vector2.new(90, 130),
	Sprite_2 = Vector2.new(150, -120),
	Brute_1 = Vector2.new(120, -200),
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
function MapLayout.height(x: number, z: number): number
	local broad = math.noise(x / 110, z / 110, 3.7)
	local detail = math.noise(x / 28, z / 28, 9.1) * 0.5
	local h = 6 + broad * 34 + detail * 5
	local p = Vector2.new(x, z)

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

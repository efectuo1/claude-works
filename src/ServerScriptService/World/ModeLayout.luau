--!strict
--[[
	Geometría de las modalidades como datos puros (sin Instances, así que se prueba sin Studio).
	Lo usan ModeArenaBuilder (construye plataformas, puentes y agua), HubBuilder (cabañas de entrada),
	WaveService y JefesService (teleports, puntos de aparición y pads).

	Arena de oleadas: plataforma central, tres plataformas de aparición (norte, este, oeste) y un lobby al sur
	con los pads de dificultad. Todo unido por puentes sobre agua.
	Sala de jefes: lobby con dos filas de pads, puente y arena circular con pilares.

	Las coordenadas son XZ en el mapa; las alturas son constantes porque las zonas son planas (MapLayout).
]]

local ServerScriptService = game:GetService("ServerScriptService")

local MapLayout = require(ServerScriptService.World.MapLayout)

export type Deck = { name: string, center: Vector2, radius: number }
export type Bridge = { from: Vector2, to: Vector2, width: number }
export type Box = { name: string, center: Vector2, size: Vector2 }

local ModeLayout = {}

-- Las modalidades viven en islas aparte, fuera del mapa principal (-320..320).
local WAVE_ISLAND = Vector2.new(2000, 0)
local BOSS_ISLAND = Vector2.new(2000, 400)
ModeLayout.ISLAND_RADIUS = 84 -- radio de la base de cada isla (la base cubre todo lo jugable)

ModeLayout.DECK_LIFT = 3 -- altura de las plataformas sobre el suelo plano
ModeLayout.WATER_RADIUS = 66
ModeLayout.FALL_DEPTH = 10 -- por debajo de este desnivel, el jugador vuelve a la plataforma central
ModeLayout.BRIDGE_WIDTH = 8
ModeLayout.PAD_SPACING = 6

-- Origen de la arena de oleadas (centro de su isla).
function ModeLayout.waveOrigin(): Vector2
	return WAVE_ISLAND
end

-- Origen de la sala de jefes (centro de su isla).
function ModeLayout.bossOrigin(): Vector2
	return BOSS_ISLAND
end

-- Altura de las plataformas: el suelo plano más la elevación.
function ModeLayout.deckY(): number
	return MapLayout.FLAT_HEIGHT + ModeLayout.DECK_LIFT
end

-- Posición donde se para un jugador sobre una plataforma (el personaje se apoya a unos 3 studs).
local function standing(position: Vector2): Vector3
	return Vector3.new(position.X, ModeLayout.deckY() + 3, position.Y)
end

local function offset(origin: Vector2, dx: number, dz: number): Vector2
	return origin + Vector2.new(dx, dz)
end

-- ---------- Arena de oleadas ----------

function ModeLayout.waveDecks(): { Deck }
	local o = ModeLayout.waveOrigin()
	return {
		{ name = "Central", center = o, radius = 22 },
		{ name = "Norte", center = offset(o, 0, -54), radius = 10 },
		{ name = "Este", center = offset(o, 54, 0), radius = 10 },
		{ name = "Oeste", center = offset(o, -54, 0), radius = 10 },
		{ name = "Lobby", center = offset(o, 0, 54), radius = 12 },
	}
end

function ModeLayout.waveBridges(): { Bridge }
	local o = ModeLayout.waveOrigin()
	local width = ModeLayout.BRIDGE_WIDTH
	return {
		{ from = o, to = offset(o, 0, -54), width = width },
		{ from = o, to = offset(o, 54, 0), width = width },
		{ from = o, to = offset(o, -54, 0), width = width },
		{ from = o, to = offset(o, 0, 54), width = width },
	}
end

-- Pads de dificultad en el lobby, en fila. El orden es el de ORDER de WaveService.
function ModeLayout.waveEntryPad(index: number): Vector2
	local lobby = offset(ModeLayout.waveOrigin(), 0, 54)
	return offset(lobby, (index - 2) * ModeLayout.PAD_SPACING, -4)
end

-- Salida de la arena: detrás de los pads, en el extremo sur del lobby.
function ModeLayout.waveExitPad(): Vector2
	return offset(ModeLayout.waveOrigin(), 0, 62)
end

-- Punto de aparición en la arena (plataforma central).
function ModeLayout.waveCenter(): Vector3
	return standing(ModeLayout.waveOrigin())
end

-- Lobby de la arena: a donde llega quien entra desde el hub.
function ModeLayout.waveLobby(): Vector3
	return standing(offset(ModeLayout.waveOrigin(), 0, 54))
end

-- Puntos de aparición de mobs: repartidos entre las plataformas norte, este y oeste.
-- Cada punto está dentro de su plataforma, con margen para que el mob no caiga.
function ModeLayout.waveSpawnPoints(count: number): { Vector2 }
	local decks = ModeLayout.waveDecks()
	local spawns = { decks[2], decks[3], decks[4] }
	local points: { Vector2 } = {}
	for index = 1, count do
		local slot = (index - 1) % #spawns
		local ring = math.floor((index - 1) / #spawns)
		local deck = spawns[slot + 1]
		local angle = slot * math.pi * 2 / #spawns + ring * 0.9
		local radius = 4 + (ring % 2) * 2.5
		table.insert(points, deck.center + Vector2.new(math.cos(angle), math.sin(angle)) * radius)
	end
	return points
end

-- ---------- Sala de jefes ----------

function ModeLayout.bossLobbyBox(): Box
	local o = ModeLayout.bossOrigin()
	return { name = "Lobby", center = offset(o, 0, -40), size = Vector2.new(48, 34) }
end

function ModeLayout.bossArena(): Deck
	return { name = "Arena", center = offset(ModeLayout.bossOrigin(), 0, 22), radius = 30 }
end

function ModeLayout.bossBridge(): Bridge
	return { from = ModeLayout.bossLobbyBox().center, to = ModeLayout.bossArena().center, width = 10 }
end

-- Pad de un jefe (fila) y dificultad (columna). Fila 1..2 y columna 1..3.
function ModeLayout.bossPad(row: number, col: number): Vector2
	local lobby = ModeLayout.bossLobbyBox().center
	return offset(lobby, (col - 2) * 12, (row - 1) * 10 - 8)
end

-- Salida de la sala: pad al sur del lobby, entre la entrada y el puente.
function ModeLayout.bossExitPad(): Vector2
	return offset(ModeLayout.bossLobbyBox().center, 0, 12)
end

-- Lobby de la sala: a donde llega quien entra desde el hub.
function ModeLayout.bossLobby(): Vector3
	return standing(ModeLayout.bossLobbyBox().center)
end

-- Centro de la arena de jefes: donde aparece el jefe y el jugador al empezar.
function ModeLayout.bossArenaPosition(): Vector3
	return standing(ModeLayout.bossArena().center)
end

-- ---------- Hub ----------

-- Punto de aparición en el hub: al sur de la fuente, cerca de las cabañas.
function ModeLayout.hubSpawn(): Vector3
	local spawn = MapLayout.HUB_SPAWN
	return Vector3.new(spawn.X, MapLayout.FLAT_HEIGHT + 3, spawn.Y)
end

return table.freeze(ModeLayout)

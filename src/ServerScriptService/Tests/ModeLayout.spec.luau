--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local MapLayout = require(ServerScriptService.World.MapLayout)
local ModeLayout = require(ServerScriptService.World.ModeLayout)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

local function inDeck(point: Vector2, deck: { center: Vector2, radius: number }, margin: number): boolean
	return (point - deck.center).Magnitude <= deck.radius - margin
end

local function inRegion(point: Vector2, id: string): boolean
	local region = MapLayout.region(id)
	return region ~= nil and (point - region.center).Magnitude < region.radius
end

return {
	run = function(): boolean
		return TestHarness.run("ModeLayout", {
			["la arena de oleadas cae dentro de su zona"] = function()
				for _, deck in ModeLayout.waveDecks() do
					expect(inRegion(deck.center, "modes"), `{deck.name} fuera de la zona de oleadas`)
				end
			end,

			["las plataformas de oleadas no se solapan"] = function()
				local decks = ModeLayout.waveDecks()
				for i = 1, #decks do
					for j = i + 1, #decks do
						local gap = (decks[i].center - decks[j].center).Magnitude
						expect(gap > decks[i].radius + decks[j].radius, `{decks[i].name} y {decks[j].name} se solapan`)
					end
				end
			end,

			["los puentes unen plataformas dentro de sus discos"] = function()
				local decks = ModeLayout.waveDecks()
				for _, bridge in ModeLayout.waveBridges() do
					local touchesA, touchesB = false, false
					for _, deck in decks do
						if inDeck(bridge.from, deck, 0) then
							touchesA = true
						end
						if inDeck(bridge.to, deck, 0) then
							touchesB = true
						end
					end
					expect(touchesA and touchesB, "un puente no une dos plataformas")
				end
			end,

			["los pads de dificultad están dentro del lobby"] = function()
				local lobby = ModeLayout.waveDecks()[5]
				for index = 1, 3 do
					expect(inDeck(ModeLayout.waveEntryPad(index), lobby, 1), `pad {index} fuera del lobby`)
				end
			end,

			["la salida de la arena está dentro del lobby"] = function()
				local lobby = ModeLayout.waveDecks()[5]
				expect(inDeck(ModeLayout.waveExitPad(), lobby, 0), "la salida queda fuera del lobby")
			end,

			["los mobs aparecen sobre las plataformas de aparición"] = function()
				local decks = ModeLayout.waveDecks()
				local spawnDecks = { decks[2], decks[3], decks[4] }
				local points = ModeLayout.waveSpawnPoints(12)
				expect(#points == 12, "debe haber un punto por mob")
				for index, point in points do
					local ok = false
					for _, deck in spawnDecks do
						if inDeck(point, deck, 1) then
							ok = true
						end
					end
					expect(ok, `el punto {index} queda fuera de las plataformas de aparición`)
				end
			end,

			["la sala de jefes tiene lobby, puente y arena dentro de su zona"] = function()
				local lobby = ModeLayout.bossLobbyBox()
				local arena = ModeLayout.bossArena()
				expect(inRegion(lobby.center, "bosses"), "el lobby está fuera de la zona de jefes")
				expect(inRegion(arena.center, "bosses"), "la arena está fuera de la zona de jefes")
				expect(inRegion(ModeLayout.bossBridge().from, "bosses"), "el puente empieza fuera")
			end,

			["los pads de jefes están dentro del lobby"] = function()
				local lobby = ModeLayout.bossLobbyBox()
				for row = 1, 2 do
					for col = 1, 3 do
						local p = ModeLayout.bossPad(row, col)
						local half = lobby.size / 2
						local dx = math.abs(p.X - lobby.center.X)
						local dz = math.abs(p.Y - lobby.center.Y)
						expect(dx < half.X - 2 and dz < half.Y - 2, `pad {row}-{col} fuera del lobby`)
					end
				end
			end,

			["la altura de las plataformas es constante y sobre el suelo"] = function()
				expect(ModeLayout.deckY() > MapLayout.FLAT_HEIGHT, "las plataformas deben estar elevadas")
				expect(ModeLayout.waveCenter().Y == ModeLayout.deckY() + 3, "el punto de aparición no está sobre la plataforma")
			end,

			["el punto de aparición del hub está en la plaza"] = function()
				local spawn = ModeLayout.hubSpawn()
				expect((Vector2.new(spawn.X, spawn.Z)).Magnitude < 40, "el hub queda fuera de la zona")
			end,
		})
	end,
}

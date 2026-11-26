--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpawnPlanner = require(ServerScriptService.Mobs.SpawnPlanner)
local Zones = require(ReplicatedStorage.Shared.Definitions.Zones)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

return {
	run = function(): boolean
		return TestHarness.run("SpawnPlanner", {
			["la zona inicial genera un slot por spawn"] = function()
				local zone = Zones.starter_ember_fields
				local result = SpawnPlanner.plan(zone)
				expect(result.ok, "la zona inicial debería ser válida")
				expect(#result.value == #zone.spawns, "un slot por punto de spawn")
			end,

			["los ids de instancia son únicos"] = function()
				local result = SpawnPlanner.plan(Zones.starter_ember_fields)
				assert(result.ok)
				local seen: { [string]: boolean } = {}
				for _, slot in result.value do
					expect(not seen[slot.instanceId], `id duplicado {slot.instanceId}`)
					seen[slot.instanceId] = true
				end
			end,

			["rechaza spawn duplicado"] = function()
				local result = SpawnPlanner.plan({
					id = "bad",
					displayName = "bad",
					spawns = {
						{ mobDefId = "ember_wolf", spawnPointName = "A", respawnSeconds = 5 },
						{ mobDefId = "ember_wolf", spawnPointName = "A", respawnSeconds = 5 },
					},
				})
				expect(not result.ok, "debería rechazar el duplicado")
			end,

			["rechaza mob desconocido"] = function()
				local result = SpawnPlanner.plan({
					id = "bad",
					displayName = "bad",
					spawns = { { mobDefId = "no_existe", spawnPointName = "A", respawnSeconds = 5 } },
				})
				expect(not result.ok, "debería rechazar el mob")
			end,

			["rechaza respawn demasiado corto"] = function()
				local result = SpawnPlanner.plan({
					id = "bad",
					displayName = "bad",
					spawns = { { mobDefId = "ember_wolf", spawnPointName = "A", respawnSeconds = 0 } },
				})
				expect(not result.ok, "debería rechazar el respawn")
			end,
		})
	end,
}

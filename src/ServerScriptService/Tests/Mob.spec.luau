--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Mob = require(ServerScriptService.Mobs.Mob)
local MobDefs = require(ReplicatedStorage.Shared.Definitions.Mobs)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

return {
	run = function(): boolean
		return TestHarness.run("Mob", {
			["cada golpe informa la vida restante"] = function()
				local seen: { number } = {}
				local mob = Mob.new("m5", MobDefs.ember_wolf, Vector3.zero, function() end, function(health: number)
					table.insert(seen, health)
				end)
				mob.takeDamage(30, 1)
				mob.takeDamage(30, 1)
				expect(#seen == 2, `debería informar 2 veces, informó {#seen}`)
				expect(seen[1] == MobDefs.ember_wolf.maxHealth - 30, "vida tras el primer golpe")
				expect(seen[2] == MobDefs.ember_wolf.maxHealth - 60, "vida tras el segundo golpe")
			end,

			["la muerte se emite una sola vez"] = function()
				local emitted = 0
				local mob = Mob.new("m1", MobDefs.ember_wolf, Vector3.zero, function()
					emitted += 1
				end)
				mob.takeDamage(60, 1)
				mob.takeDamage(60, 2)
				mob.takeDamage(60, 3)
				expect(emitted == 1, `debería emitir una vez, emitió {emitted}`)
				expect(mob.getState() == "Dead", "debería estar muerto")
			end,

			["el último golpe recibe el crédito y todos los que atacaron cuentan"] = function()
				local received: any = nil
				local mob = Mob.new("m2", MobDefs.ember_wolf, Vector3.zero, function(event)
					received = event
				end)
				mob.takeDamage(10, 1)
				mob.takeDamage(100, 2)
				expect(received ~= nil, "debería haber evento")
				expect(received.killerUserId == 2, "el killer debería ser el último golpe")
				expect(#received.contributorUserIds == 2, "deberían contar ambos jugadores")
			end,

			["el daño no baja la vida por debajo de cero"] = function()
				local mob = Mob.new("m3", MobDefs.ash_brute, Vector3.zero, function() end)
				mob.takeDamage(9999, 1)
				expect(mob.getHealth() == 0, "la vida no debería ser negativa")
			end,

			["un mob que no ve objetivo patrulla y no se mueve"] = function()
				local mob = Mob.new("m4", MobDefs.ember_sprite, Vector3.new(0, 0, 0), function() end)
				expect(mob.update(nil) == "Patrol", "debería seguir patrullando")
			end,
		})
	end,
}

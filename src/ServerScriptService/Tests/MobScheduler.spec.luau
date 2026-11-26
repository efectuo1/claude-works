--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local MobScheduler = require(ServerScriptService.Mobs.MobScheduler)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

return {
	run = function(): boolean
		return TestHarness.run("MobScheduler", {
			["ejecuta el tick de cada job activo en un ciclo"] = function()
				local calls = 0
				local active = true
				MobScheduler.add({
					tick = function()
						calls += 1
					end,
					isActive = function()
						return active
					end,
				})
				MobScheduler.stepOnce()
				expect(calls >= 1, "el job debería ejecutarse")
				active = false
				MobScheduler.stepOnce()
			end,

			["un job que falla no impide ejecutar a los demás"] = function()
				-- Los jobs de prueba se retiran solos: el bucle real es global y no debe quedarse con ellos.
				local reached = false
				local failed = false
				MobScheduler.add({
					tick = function()
						failed = true
						error("fallo intencional")
					end,
					isActive = function()
						return not failed
					end,
				})
				MobScheduler.add({
					tick = function()
						reached = true
					end,
					isActive = function()
						return not reached
					end,
				})
				MobScheduler.stepOnce()
				expect(reached, "el segundo job debería ejecutarse")
			end,

			["retira los jobs inactivos del registro"] = function()
				local before = MobScheduler.count()
				MobScheduler.add({
					tick = function() end,
					isActive = function()
						return false
					end,
				})
				expect(MobScheduler.count() == before + 1, "el job debería registrarse")
				MobScheduler.stepOnce()
				expect(MobScheduler.count() == before, "el job inactivo debería retirarse")
			end,
		})
	end,
}

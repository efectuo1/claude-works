--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Progression = require(ReplicatedStorage.Shared.Util.Progression)
local TestHarness = require(script.Parent.TestHarness)
local expect = TestHarness.expect

return {
	run = function(): boolean
		return TestHarness.run("Progression", {
			["el nivel 1 empieza en 0 XP"] = function()
				expect(Progression.xpForLevel(1) == 0, "nivel 1 = 0 XP")
				expect(Progression.levelForXp(0) == 1, "0 XP = nivel 1")
			end,

			["los umbrales de habilidades: nivel 10 y 25"] = function()
				expect(Progression.xpForLevel(10) == 810, "nivel 10 = 810 XP")
				expect(Progression.xpForLevel(25) == 5760, "nivel 25 = 5760 XP")
				expect(Progression.levelForXp(809) == 9, "un punto antes del 10 sigue en 9")
				expect(Progression.levelForXp(810) == 10, "en 810 XP se llega al 10")
			end,

			["el nivel no pasa del máximo"] = function()
				expect(Progression.levelForXp(10000000) == Progression.MAX_LEVEL, "tope de nivel")
			end,
		})
	end,
}

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DailyReward = require(ReplicatedStorage.Shared.Util.DailyReward)
local TestHarness = require(script.Parent.TestHarness)
local expect = TestHarness.expect

return {
	run = function(): boolean
		return TestHarness.run("DailyReward", {
			["el primer día da racha 1"] = function()
				local result = DailyReward.claim(DailyReward.empty(), 100)
				expect(result.ok and result.value.streak == 1, "la primera reclamación debe dar racha 1")
			end,

			["reclamar dos veces el mismo día se rechaza"] = function()
				local first = DailyReward.claim(DailyReward.empty(), 100)
				expect(first.ok, "la primera debe funcionar")
				local second = DailyReward.claim(first.value.state, 100)
				expect(not second.ok and second.error == "ya_reclamado_hoy", "el segundo intento debe rechazarse")
			end,

			["días seguidos suman racha"] = function()
				local state = DailyReward.empty()
				for day = 100, 103 do
					local result = DailyReward.claim(state, day)
					expect(result.ok, `día {day} debe reclamarse`)
					state = result.value.state
				end
				expect(state.streak == 4, `la racha debe ser 4 y es {state.streak}`)
			end,

			["saltarse un día reinicia la racha"] = function()
				local state = { lastDay = 100, streak = 5 }
				local result = DailyReward.claim(state, 102)
				expect(result.ok and result.value.streak == 1, "tras saltar un día la racha vuelve a 1")
			end,

			["el premio hace ciclo cada 7 días"] = function()
				local state = { lastDay = 106, streak = 7 }
				local status = DailyReward.status(state, 107)
				expect(status.cycleDay == 1, `el día 8 de racha debe ser el día 1 del ciclo y es {status.cycleDay}`)
			end,

			["el estado de hoy indica si ya se reclamó"] = function()
				local status = DailyReward.status({ lastDay = 100, streak = 2 }, 100)
				expect(status.claimedToday, "hoy debe figurar como reclamado")
				expect(status.streak == 2, "la racha no debe cambiar al consultar")
			end,

			["cada día del ciclo tiene un premio"] = function()
				for index, reward in DailyReward.days() do
					expect(reward.gold ~= nil or reward.gems ~= nil or reward.itemId ~= nil, `día {index} sin premio`)
				end
			end,
		})
	end,
}

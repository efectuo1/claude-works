--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlaytimeRewards = require(ReplicatedStorage.Shared.Util.PlaytimeRewards)
local TestHarness = require(script.Parent.TestHarness)
local expect = TestHarness.expect

return {
	run = function(): boolean
		return TestHarness.run("PlaytimeRewards", {
			["nada está listo antes de 15 minutos"] = function()
				expect(#PlaytimeRewards.ready(14 * 60, {}) == 0, "antes de 15 min no debe haber premios")
			end,

			["a los 15 minutos el primer premio está listo"] = function()
				local ready = PlaytimeRewards.ready(15 * 60, {})
				expect(#ready == 1 and ready[1] == 1, "solo el primer hito debe estar listo")
			end,

			["más tiempo desbloquea más hitos"] = function()
				expect(#PlaytimeRewards.ready(90 * 60, {}) == 4, "a 90 min deben estar listos cuatro hitos")
			end,

			["reclamar dos veces el mismo hito se rechaza"] = function()
				local claimed: { [number]: boolean } = {}
				expect(PlaytimeRewards.claim(1, 15 * 60, claimed).ok, "la primera reclamación debe funcionar")
				local again = PlaytimeRewards.claim(1, 15 * 60, claimed)
				expect(not again.ok and again.error == "ya_reclamado", "la segunda debe rechazarse")
			end,

			["no se puede reclamar un hito sin tiempo"] = function()
				local result = PlaytimeRewards.claim(3, 10 * 60, {})
				expect(not result.ok and result.error == "aun_no_disponible", "un hito no alcanzado no se reclama")
			end,

			["los premios mejoran con el tiempo"] = function()
				local tiers = PlaytimeRewards.tiers()
				for index = 2, #tiers do
					expect(tiers[index].minutes > tiers[index - 1].minutes, "los minutos deben crecer")
				end
			end,
		})
	end,
}

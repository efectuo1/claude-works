--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Contribution = require(ReplicatedStorage.Shared.Util.Contribution)
local Rewards = require(ReplicatedStorage.Shared.Util.Rewards)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

return {
	run = function(): boolean
		return TestHarness.run("Contribution", {
			["quien mata solo tiene el 100 %"] = function()
				local shares = Contribution.shares({ [1] = 500 }, { 1 })
				expect(near(shares[1], 1), "el asesino en solitario debe tener share 1")
			end,

			["el reparto es proporcional al daño"] = function()
				local shares = Contribution.shares({ [1] = 300, [2] = 100 }, { 1, 2 })
				expect(near(shares[1], 0.75) and near(shares[2], 0.25), "debe ser 75 % y 25 %")
			end,

			["los porcentajes suman exactamente 1"] = function()
				local shares = Contribution.shares({ [1] = 7, [2] = 11, [3] = 13 }, { 1, 2, 3 })
				local total = 0
				for _, share in shares do
					total += share
				end
				expect(near(total, 1), `la suma debe ser 1, es {total}`)
			end,

			["el daño cero o negativo no cuenta"] = function()
				local shares = Contribution.shares({ [1] = 100, [2] = 0, [3] = -5 }, { 1, 2, 3 })
				expect(shares[1] == 1 and shares[2] == nil and shares[3] == nil, "solo quien hizo daño participa")
			end,

			["sin daño registrado se reparte a partes iguales"] = function()
				local shares = Contribution.shares(nil, { 1, 2, 3, 4 })
				expect(near(shares[1], 0.25) and near(shares[4], 0.25), "cada uno debe tener 25 %")
			end,

			["sin nadie no hay reparto"] = function()
				expect(next(Contribution.shares(nil, {})) == nil, "no debe haber participaciones")
			end,

			["share 1 siempre consigue la parte y share 0 nunca"] = function()
				local always = Contribution.attempt(1, function()
					return 0.999
				end)
				local never = Contribution.attempt(0, function()
					return 0
				end)
				expect(always and not never, "los extremos deben ser exactos")
			end,

			["share 0.5 gana cuando el azar cae por debajo"] = function()
				expect(Contribution.attempt(0.5, function()
					return 0.4
				end), "0.4 < 0.5 debe ganar")
				expect(not Contribution.attempt(0.5, function()
					return 0.6
				end), "0.6 >= 0.5 debe perder")
			end,

			["en grupo el total esperado es el mismo que en solitario"] = function()
				local rng = Random.new(42)
				local function random(): number
					return rng:NextNumber()
				end
				local shares = Contribution.shares({ [1] = 1, [2] = 1, [3] = 1, [4] = 1 }, { 1, 2, 3, 4 })
				local hits = 0
				local trials = 20000
				for _ = 1, trials do
					for _, share in shares do
						if Contribution.attempt(share, random) then
							hits += 1
						end
					end
				end
				-- Sin grupo, el asesino tiene 1 de probabilidad por tirada: total = trials.
				local expected = trials
				expect(math.abs(hits - expected) / expected < 0.02, `el grupo produjo {hits}, se esperaba ~{expected}`)
			end,

			["la participación escala la probabilidad de gema"] = function()
				local rank = Rewards.rankOrDefault("novato")
				local rng = Random.new(7)
				local gemsWithZeroShare = 0
				for _ = 1, 3000 do
					gemsWithZeroShare += Rewards.rollMob("ash_brute", rank, rng, 0).gems
				end
				expect(gemsWithZeroShare == 0, "con participación 0 no debe salir ninguna gema")
			end,
		})
	end,
}

--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Rewards = require(Shared.Util.Rewards)
local Economy = require(Shared.Definitions.Economy)
local Perks = require(Shared.Util.Perks)
local Shop = require(Shared.Definitions.Shop)
local Ranks = require(Shared.Definitions.Ranks)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

return {
	run = function(): boolean
		return TestHarness.run("Rewards", {
			["el oro de un mob cae dentro de su rango"] = function()
				local rank = Rewards.rankOrDefault("novato")
				local entry = Economy.MOBS.ember_wolf
				local rng = Random.new(1)
				for _ = 1, 200 do
					local grant = Rewards.rollMob("ember_wolf", rank, rng)
					expect(grant.gold >= entry.goldMin and grant.gold <= entry.goldMax, `oro fuera de rango: {grant.gold}`)
				end
			end,

			["un mob sin datos no da nada"] = function()
				local grant = Rewards.rollMob("no_existe", Rewards.rankOrDefault("novato"), Random.new(1))
				expect(grant.gold == 0 and grant.gems == 0, "un mob sin datos no debe dar recompensa")
			end,

			["las gemas son escasas en todos los rangos"] = function()
				for _, rank in Ranks do
					for mobId, entry in Economy.MOBS do
						expect(entry.gemChance * rank.gemMult <= 0.25, `{mobId} en {rank.id} da demasiadas gemas`)
					end
				end
			end,

			["el oro sube con la dificultad del mob"] = function()
				local wolf = Economy.MOBS.ember_wolf
				local brute = Economy.MOBS.ash_brute
				expect(brute.goldMin > wolf.goldMax, "un élite debe dar más oro que un lobo")
			end,

			["los rangos mejoran oro, gemas y suerte a la vez"] = function()
				for index = 2, #Ranks do
					local prev, rank = Ranks[index - 1], Ranks[index]
					expect(rank.goldMult >= prev.goldMult, `{rank.id} da menos oro que {prev.id}`)
					expect(rank.gemMult >= prev.gemMult, `{rank.id} da menos gemas que {prev.id}`)
					expect(rank.luck >= prev.luck, `{rank.id} tiene menos suerte que {prev.id}`)
				end
			end,

			["el coste de cada rango sube con el nivel"] = function()
				for index = 2, #Ranks do
					expect(Ranks[index].minLevel > Ranks[index - 1].minLevel, "el nivel mínimo debe subir")
					expect(Ranks[index].cost.gold > Ranks[index - 1].cost.gold, "el coste en oro debe subir")
				end
			end,

			["un jefe siempre da al menos una gema"] = function()
				local rng = Random.new(3)
				for _ = 1, 50 do
					local grant = Rewards.rollBoss(Rewards.rankOrDefault("novato"), rng)
					expect(grant.gems >= 1, "el jefe debe garantizar una gema")
				end
			end,

			["no se puede subir de rango sin nivel"] = function()
				local result = Rewards.canRankUp(5, 99999, 99, "novato")
				expect(not result.ok and result.error == "nivel_insuficiente", "debe fallar por nivel")
			end,

			["no se puede subir de rango sin oro"] = function()
				local result = Rewards.canRankUp(10, 0, 0, "novato")
				expect(not result.ok and result.error == "oro_insuficiente", "debe fallar por oro")
			end,

			["con nivel y oro suficientes se sube al siguiente rango"] = function()
				local result = Rewards.canRankUp(10, 500, 0, "novato")
				expect(result.ok and result.value.id == "aprendiz", "debe subir a aprendiz")
			end,

			["en grupo el oro del mob se reparte según el daño"] = function()
				local rank = Rewards.rankOrDefault("novato")
				local a = Rewards.rollMob("ember_wolf", rank, Random.new(1), 0.25, 100)
				local b = Rewards.rollMob("ember_wolf", rank, Random.new(2), 0.75, 100)
				expect(a.gold == 25 and b.gold == 75, `reparto incorrecto: {a.gold} y {b.gold}`)
			end,

			["el oro repartido suma el oro del mob"] = function()
				local rank = Rewards.rankOrDefault("novato")
				local a = Rewards.rollMob("ember_wolf", rank, Random.new(1), 0.5, 100)
				local b = Rewards.rollMob("ember_wolf", rank, Random.new(2), 0.5, 100)
				expect(a.gold + b.gold == 100, `la suma debe ser 100 y es {a.gold + b.gold}`)
			end,

			["el que mata solo se queda con todo el oro del mob"] = function()
				local grant = Rewards.rollMob("ember_wolf", Rewards.rankOrDefault("novato"), Random.new(1), 1, 30)
				expect(grant.gold == 30, `debe ser 30 y es {grant.gold}`)
			end,

			["el rango sigue multiplicando la parte de cada jugador"] = function()
				local grant = Rewards.rollMob("ember_wolf", Rewards.rankOrDefault("leyenda"), Random.new(1), 0.5, 100)
				expect(grant.gold == 100, `leyenda con la mitad de 100 debe dar 100 y da {grant.gold}`)
			end,

			["un mob sin datos no tiene oro que repartir"] = function()
				expect(Rewards.rollMobPool("no_existe", Random.new(1)) == 0, "debe ser 0")
			end,

			["el cambio de oro a gemas usa la tasa de Economy"] = function()
				local result = Rewards.exchange("goldToGems", 2, { gold = 500, gems = 0 })
				expect(result.ok and result.value.gold == 100 and result.value.gems == 2, "2 gemas cuestan 400 oro y de 500 deben quedar 100")
			end,

			["no se cambia más oro del que hay"] = function()
				local result = Rewards.exchange("goldToGems", 3, { gold = 500, gems = 0 })
				expect(not result.ok and result.error == "oro_insuficiente", "3 gemas cuestan 600 oro")
			end,

			["el cambio de gemas a oro devuelve oro según la tasa"] = function()
				local result = Rewards.exchange("gemsToGold", 1, { gold = 0, gems = 1 })
				expect(result.ok and result.value.gold == 200 and result.value.gems == 0, "1 gema da 200 oro")
			end,

			["no se puede cambiar más gemas de las que hay"] = function()
				local result = Rewards.exchange("gemsToGold", 2, { gold = 0, gems = 1 })
				expect(not result.ok and result.error == "gemas_insuficientes", "faltan gemas")
			end,

			["cantidades y direcciones inválidas se rechazan"] = function()
				local balance = { gold = 1e6, gems = 1e6 }
				for _, amount in { 0, -1, 0.5, 0 / 0, 1e9 } do
					local result = Rewards.exchange("goldToGems", amount, balance)
					expect(not result.ok and result.error == "cantidad_invalida", `cantidad {amount} debe rechazarse`)
				end
				local result = Rewards.exchange("oro_a_gemas", 1, balance)
				expect(not result.ok and result.error == "direccion_invalida", "dirección desconocida")
			end,

			["sin pases los efectos son neutros"] = function()
				local perks = Perks.fromPasses(Shop.GAMEPASSES, function(_id: string): boolean return false end)
				expect(perks.goldMult == 1 and perks.gemMult == 1 and perks.luck == 0, "sin pases debe ser 1, 1, 0")
			end,

			["el pase de oro duplica el oro del que lo tiene"] = function()
				local perks = Perks.fromPasses(Shop.GAMEPASSES, function(id: string): boolean return id == "doble_oro" end)
				local grant = Rewards.rollMob("ember_wolf", Rewards.rankOrDefault("novato"), Random.new(1), 1, 100, perks)
				expect(grant.gold == 200, `con oro x2 debe dar 200 y da {grant.gold}`)
			end,

			["la suerte de varios pases se suma y tiene tope"] = function()
				local perks = Perks.combine({ { luck = 0.5 }, { luck = 0.5 } })
				expect(perks.luck == Perks.LUCK_CAP, `la suerte debe quedar en {Perks.LUCK_CAP} y queda {perks.luck}`)
			end,

			["el pase de gemas multiplica la probabilidad de gema"] = function()
				local perks = Perks.fromPasses(Shop.GAMEPASSES, function(id: string): boolean return id == "gemas_x2" end)
				expect(perks.gemMult == 2, "gemas x2 debe multiplicar por 2")
			end,

			["el rango máximo no tiene siguiente"] = function()
				local result = Rewards.canRankUp(999, 1e9, 1e9, "leyenda")
				expect(not result.ok and result.error == "rango_maximo", "leyenda es el máximo")
			end,
		})
	end,
}

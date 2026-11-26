--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DropService = require(ServerScriptService.Drops.DropService)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

local TABLE = {
	entries = {
		{ itemId = "comun", weight = 90, minQuantity = 1, maxQuantity = 1 },
		{ itemId = "raro", weight = 10, minQuantity = 1, maxQuantity = 1 },
	},
}

-- Cuenta cuántas veces sale "raro" en N tiradas con una semilla fija (reproducible).
local function countRare(luck: number, seed: number, rolls: number): number
	local rng = Random.new(seed)
	local service = DropService.new({ t = TABLE }, function()
		return rng:NextNumber()
	end)
	expect(service.ok, "la tabla de prueba debe ser válida")
	local rare = 0
	for _ = 1, rolls do
		local roll = service.value.roll("t", luck)
		expect(roll.ok, "la tirada debe funcionar")
		if roll.value.itemId == "raro" then
			rare += 1
		end
	end
	return rare
end

return {
	run = function(): boolean
		return TestHarness.run("DropLuck", {
			["sin suerte el reparto es el original"] = function()
				local withoutArgument = DropService.new({ t = TABLE }, (function()
					local rng = Random.new(5)
					return function()
						return rng:NextNumber()
					end
				end)())
				local withZero = DropService.new({ t = TABLE }, (function()
					local rng = Random.new(5)
					return function()
						return rng:NextNumber()
					end
				end)())
				expect(withoutArgument.ok and withZero.ok, "ambas tablas deben ser válidas")
				for _ = 1, 100 do
					local a = withoutArgument.value.roll("t")
					local b = withZero.value.roll("t", 0)
					expect(a.ok and b.ok and a.value.itemId == b.value.itemId, "con suerte 0 debe coincidir")
				end
			end,

			["con suerte salen más objetos raros"] = function()
				local base = countRare(0, 11, 20000)
				local lucky = countRare(0.5, 11, 20000)
				expect(lucky > base * 1.5, `suerte no ayuda: {base} sin suerte, {lucky} con suerte`)
			end,

			["la suerte fuera de rango se limita y no rompe la tirada"] = function()
				local rare = countRare(5, 11, 2000)
				expect(rare > 0 and rare < 2000, "con suerte exagerada debe seguir habiendo variedad")
			end,

			["una suerte negativa se trata como cero"] = function()
				expect(countRare(-1, 11, 2000) == countRare(0, 11, 2000), "la suerte negativa debe ignorarse")
			end,
		})
	end,
}

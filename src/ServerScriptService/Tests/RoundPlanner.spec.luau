--!strict
-- Ejecutar desde un Script temporal en Studio: require(...).run().
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local RoundPlanner = require(Shared.Util.RoundPlanner)
local MobDefs = require(Shared.Definitions.Mobs)

local function expect(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

local tests: { [string]: () -> () } = {
	["la primera ronda tiene cuatro mobs normales"] = function()
		local result = RoundPlanner.plan(1)
		expect(result.ok and #result.value == 4, "la ronda 1 debería tener 4 mobs")
	end,

	["la cantidad sube con cada ronda"] = function()
		local two = RoundPlanner.plan(2)
		local three = RoundPlanner.plan(3)
		expect(two.ok and three.ok and #three.value > #two.value, "la ronda 3 debería tener más que la 2")
	end,

	["la cantidad tiene tope"] = function()
		local result = RoundPlanner.plan(50)
		expect(result.ok and #result.value <= 12 + 1, "debería respetar el tope de mobs normales")
	end,

	["cada 5 rondas aparece el mob fuerte"] = function()
		local result = RoundPlanner.plan(5)
		expect(result.ok, "la ronda 5 debería planificarse")
		local last = result.value[#result.value]
		expect(last == "ash_brute", "la última de la ronda 5 debería ser el mob fuerte")
		local normal = RoundPlanner.plan(4)
		expect(normal.ok and normal.value[#normal.value] ~= "ash_brute", "la ronda 4 no debería tenerlo")
	end,

	["una ronda inválida se rechaza"] = function()
		expect(not RoundPlanner.plan(0).ok, "la ronda 0 no existe")
		expect(not RoundPlanner.plan(1.5).ok, "las rondas son enteras")
	end,

	["todos los mobs que produce existen en las definiciones"] = function()
		for _, id in RoundPlanner.possibleMobIds() do
			expect(MobDefs[id] ~= nil, `mob desconocido en rondas: {id}`)
		end
	end,
}

local function run(): boolean
	local allOk = true
	for name, test in tests do
		local ok, err = pcall(test)
		if not ok then
			allOk = false
		end
		print(if ok then "PASS" else "FAIL", name, if ok then "" else tostring(err))
	end
	return allOk
end

return { run = run }

--!strict
-- Ejecutar desde un Script temporal en Studio: require(...).run().
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DropService = require(ServerScriptService.Drops.DropService)
local Types = require(ReplicatedStorage.Shared.Types)

local function sequence(values: { number }): () -> number
	local index = 0
	return function(): number
		index += 1
		return values[index]
	end
end

local function expect(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

local sampleTable: Types.DropTable = {
	entries = {
		{ itemId = "a", weight = 70, minQuantity = 1, maxQuantity = 3 },
		{ itemId = "b", weight = 30, minQuantity = 1, maxQuantity = 1 },
	},
}

local tests: { [string]: () -> () } = {
	["tabla con peso cero se rechaza al construir"] = function()
		local bad: Types.DropTable = { entries = { { itemId = "x", weight = 0, minQuantity = 1, maxQuantity = 1 } } }
		local result = DropService.new({ bad = bad }, sequence({ 0 }))
		expect(not result.ok, "debería fallar la validación")
	end,

	["roll bajo selecciona la primera entrada"] = function()
		local result = DropService.new({ t = sampleTable }, sequence({ 0, 0 }))
		assert(result.ok)
		local roll = result.value.roll("t")
		expect(roll.ok and roll.value.itemId == "a", "debería salir 'a'")
	end,

	["roll alto selecciona la última entrada"] = function()
		local result = DropService.new({ t = sampleTable }, sequence({ 0.999, 0 }))
		assert(result.ok)
		local roll = result.value.roll("t")
		expect(roll.ok and roll.value.itemId == "b", "debería salir 'b'")
	end,

	["la cantidad respeta el rango min/max"] = function()
		local result = DropService.new({ t = sampleTable }, sequence({ 0, 0.999 }))
		assert(result.ok)
		local roll = result.value.roll("t")
		expect(roll.ok and roll.value.quantity == 3, "debería dar la cantidad máxima")
	end,

	["tabla desconocida devuelve error"] = function()
		local result = DropService.new({ t = sampleTable }, sequence({ 0 }))
		assert(result.ok)
		expect(not result.value.roll("nope").ok, "debería fallar")
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

--!strict
-- Ejecutar desde un Script temporal en Studio: require(...).run().
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roulette = require(ReplicatedStorage.Shared.Definitions.Roulette)
local TestConfig = require(ReplicatedStorage.Shared.Definitions.TestConfig)
local RouletteService = require(ServerScriptService.Roulette.RouletteService)
local Result = require(ReplicatedStorage.Shared.Util.Result)

local function expect(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

local TWO_PRIZES: { Roulette.Prize } = {
	{ id = "a", label = "A", kind = "gold", amount = 1, weight = 1 },
	{ id = "b", label = "B", kind = "gem", amount = 1, weight = 3 },
}

local function makeService(roll: number, deliverOk: boolean)
	local clock = 100
	local service = RouletteService.new({
		now = function(): number
			return clock
		end,
		allowRequest = function(_userId: number): boolean
			return true
		end,
		random = function(): number
			return roll
		end,
		deliver = function(_userId: number, _prize: Roulette.Prize): Result.Result<boolean>
			if deliverOk then
				return Result.ok(true)
			end
			return Result.err("sin_espacio")
		end,
		cooldownSeconds = 10,
	})
	return service, function(seconds: number)
		clock += seconds
	end
end

local tests: { [string]: () -> () } = {
	["los premios de la tabla real son válidos"] = function()
		local problem = Roulette.validate(Roulette.prizes())
		expect(problem == nil, `tabla de premios inválida: {problem}`)
	end,

	["un id repetido se detecta"] = function()
		local bad: { Roulette.Prize } = {
			{ id = "x", label = "X", kind = "gold", amount = 1, weight = 1 },
			{ id = "x", label = "X2", kind = "gold", amount = 1, weight = 1 },
		}
		expect(Roulette.validate(bad) ~= nil, "debería detectar el id repetido")
	end,

	["el reparto respeta los pesos"] = function()
		-- Pesos 1 y 3: roll 0.1 cae en A (0.1*4 = 0.4 < 1); roll 0.5 cae en B (2 >= 1).
		expect(Roulette.pick(TWO_PRIZES, 0.1) == TWO_PRIZES[1], "0.1 debería dar A")
		expect(Roulette.pick(TWO_PRIZES, 0.5) == TWO_PRIZES[2], "0.5 debería dar B")
		expect(Roulette.pick(TWO_PRIZES, 0.999) == TWO_PRIZES[2], "casi 1 debería dar B")
	end,

	["una lista vacía no da premio"] = function()
		expect(Roulette.pick({}, 0.5) == nil, "sin premios no debería haber resultado")
	end,

	["un giro entrega el premio elegido"] = function()
		local service = makeService(0.1, true)
		local result = service.spin(1)
		expect(result.ok, "el giro debería funcionar")
		expect(result.value.id == Roulette.prizes()[1].id, "debería tocar el premio del roll")
	end,

	["el enfriamiento solo se aplica si está activo"] = function()
		local service, advance = makeService(0.5, true)
		service.spin(1)
		local second = service.spin(1)
		if TestConfig.NO_COOLDOWNS then
			expect(second.ok, "con modo de pruebas no debe haber enfriamiento")
		else
			expect(not second.ok and second.error == "cooldown", "debería bloquearse")
			advance(10)
			expect(service.spin(1).ok, "debería volver tras el enfriamiento")
		end
	end,

	["si la entrega falla no hay premio ni enfriamiento"] = function()
		local service = makeService(0.5, false)
		local result = service.spin(1)
		expect(not result.ok and result.error == "sin_espacio", "debería reportar el fallo de entrega")
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

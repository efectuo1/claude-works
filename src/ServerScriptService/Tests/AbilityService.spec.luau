--!strict
-- Ejecutar desde un Script temporal en Studio: require(...).run().
-- Los casos de niveles y cooldowns se adaptan a TestConfig: con el modo de pruebas activo, no deben bloquear.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AbilityService = require(ServerScriptService.Combat.AbilityService)
local TestConfig = require(ReplicatedStorage.Shared.Definitions.TestConfig)

type Fake = {
	position: Vector3,
	damage: number,
	takeDamage: (amount: number, _source: number) -> (),
	getPosition: () -> Vector3,
}

local function makeFake(position: Vector3): Fake
	local fake = { position = position, damage = 0 }
	fake.getPosition = function(): Vector3
		return fake.position
	end
	fake.takeDamage = function(amount: number, _source: number)
		fake.damage += amount
	end
	return fake :: any
end

local function makeHarness(targets: { [string]: Fake })
	local clock = 100
	local level = 1
	local pending: { { at: number, fn: () -> () } } = {}
	local service = AbilityService.new({
		now = function(): number
			return clock
		end,
		allowRequest = function(_userId: number): boolean
			return true
		end,
		getLevel = function(_userId: number): number?
			return level
		end,
		getPosition = function(_userId: number): Vector3?
			return Vector3.zero
		end,
		registryFor = function(_userId: number)
			return {
				get = function(id: string)
					return targets[id]
				end,
				near = function(origin: Vector3, radius: number)
					local found = {}
					for _, fake in targets do
						local delta = fake.getPosition() - origin
						if Vector3.new(delta.X, 0, delta.Z).Magnitude <= radius then
							table.insert(found, fake)
						end
					end
					return found
				end,
			}
		end,
		schedule = function(seconds: number, fn: () -> ())
			table.insert(pending, { at = clock + seconds, fn = fn })
		end,
	})
	return {
		service = service,
		advance = function(seconds: number)
			clock += seconds
		end,
		-- Ejecuta los golpes diferidos cuyo instante ya llegó.
		flush = function()
			for _, item in pending do
				if item.at <= clock then
					item.fn()
				end
			end
		end,
	}
end

local function expect(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

local tests: { [string]: () -> () } = {
	["golpe simple aplica su daño"] = function()
		local dummy = makeFake(Vector3.new(5, 0, 0))
		local h = makeHarness({ dummy = dummy })
		local result = h.service.cast(1, { abilityId = "punch_magma", targetId = "dummy" })
		expect(result.ok, "debería ser válido")
		expect(dummy.damage == 40, "daño incorrecto")
	end,

	["objetivo fuera de alcance se rechaza"] = function()
		local far = makeFake(Vector3.new(100, 0, 0))
		local h = makeHarness({ far = far })
		local result = h.service.cast(1, { abilityId = "punch_magma", targetId = "far" })
		expect(not result.ok and result.error == "out_of_range", "debería estar fuera de alcance")
		expect(far.damage == 0, "no debería haber daño")
	end,

	["habilidad de un objetivo sin targetId según el modo de pruebas"] = function()
		local h = makeHarness({})
		local result = h.service.cast(1, { abilityId = "punch_magma" })
		if TestConfig.ALLOW_CAST_WITHOUT_TARGET then
			expect(result.ok and result.value.damage == 0, "con modo de pruebas debe lanzarse con daño 0")
		else
			expect(not result.ok and result.error == "payload_invalid", "debería exigir objetivo")
		end
	end,

	["área sin enemigos según el modo de pruebas"] = function()
		local h = makeHarness({})
		local result = h.service.cast(1, { abilityId = "ash_storm" })
		if TestConfig.ALLOW_CAST_WITHOUT_TARGET then
			expect(result.ok and result.value.hits == 0, "con modo de pruebas el área sale sin golpes")
		else
			expect(not result.ok and result.error == "no_targets", "debería decir que no hay enemigos")
		end
	end,

	["cooldown se respeta solo si está activo"] = function()
		local dummy = makeFake(Vector3.new(5, 0, 0))
		local h = makeHarness({ dummy = dummy })
		h.service.cast(1, { abilityId = "punch_magma", targetId = "dummy" })
		local second = h.service.cast(1, { abilityId = "punch_magma", targetId = "dummy" })
		if TestConfig.NO_COOLDOWNS then
			expect(second.ok, "con modo de pruebas no debe haber cooldown")
		else
			expect(not second.ok and second.error == "cooldown", "debería bloquearse por cooldown")
		end
	end,

	["niveles se respetan solo si están activos"] = function()
		local dummy = makeFake(Vector3.new(5, 0, 0))
		local h = makeHarness({ dummy = dummy })
		local result = h.service.cast(1, { abilityId = "smoke_clone", targetId = "dummy" })
		if TestConfig.NO_LEVELS then
			expect(result.ok, "con modo de pruebas no debe haber nivel mínimo")
		else
			expect(not result.ok and result.error == "locked", "debería estar bloqueada")
		end
	end,

	["área golpea a todos los enemigos cercanos"] = function()
		local a = makeFake(Vector3.new(3, 0, 0))
		local b = makeFake(Vector3.new(0, 0, 6))
		local far = makeFake(Vector3.new(60, 0, 0))
		local h = makeHarness({ a = a, b = b, far = far })
		local result = h.service.cast(1, { abilityId = "ash_storm" })
		expect(result.ok, "el área debería funcionar")
		expect(result.value.hits == 2, "deberían ser 2 golpeados")
		expect(a.damage == 30 and b.damage == 30, "daño de área incorrecto")
		expect(far.damage == 0, "el lejano no debería recibir daño")
	end,

	["área sin enemigos se rechaza fuera del modo de pruebas"] = function()
		local far = makeFake(Vector3.new(60, 0, 0))
		local h = makeHarness({ far = far })
		local result = h.service.cast(1, { abilityId = "ash_storm" })
		if not TestConfig.ALLOW_CAST_WITHOUT_TARGET then
			expect(not result.ok and result.error == "no_targets", "debería decir que no hay enemigos")
		else
			expect(result.ok, "con modo de pruebas el área sale igual")
		end
	end,

	["multi-golpe aplica sus tres golpes en el tiempo"] = function()
		local dummy = makeFake(Vector3.new(5, 0, 0))
		local h = makeHarness({ dummy = dummy })
		local result = h.service.cast(1, { abilityId = "smoke_clone", targetId = "dummy" })
		expect(result.ok, "debería ser válido")
		expect(dummy.damage == 18, "el primer golpe es inmediato")
		h.advance(1)
		h.flush()
		expect(dummy.damage == 54, "tres golpes de 18 deberían sumar 54")
	end,

	["multi-golpe no daña a un objetivo que ya murió"] = function()
		local dummy = makeFake(Vector3.new(5, 0, 0))
		local targets: { [string]: Fake } = { dummy = dummy }
		local h = makeHarness(targets)
		h.service.cast(1, { abilityId = "smoke_clone", targetId = "dummy" })
		-- Simula muerte: el objetivo sale del registro antes de los golpes diferidos.
		targets.dummy = nil
		h.advance(1)
		h.flush()
		expect(dummy.damage == 18, "solo debería contar el primer golpe")
	end,

	["payload malformado se rechaza sin tocar el estado"] = function()
		local dummy = makeFake(Vector3.new(5, 0, 0))
		local h = makeHarness({ dummy = dummy })
		local result = h.service.cast(1, "basura")
		expect(not result.ok and result.error == "payload_invalid", "debería rechazar el payload")
		expect(dummy.damage == 0, "no debería haber daño")
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

--!strict
--[[
	Servicio de habilidades (autoritativo en servidor).
	Valida una intención de lanzar una habilidad y, solo si es válida, aplica el efecto.
	Tipos: single (un objetivo), multi (un objetivo, varios golpes) y area (todos los enemigos cercanos).
	Niveles y cooldowns se saltan mientras TestConfig lo indique (modo de pruebas).
	No conoce Players, Remotes ni workspace: todo llega por dependencias inyectadas.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Abilities = require(Shared.Definitions.Abilities)
local TestConfig = require(Shared.Definitions.TestConfig)
local Result = require(Shared.Util.Result)
local Types = require(Shared.Types)

export type TargetLookup = {
	get: (targetId: string) -> Types.CombatTarget?,
	near: (origin: Vector3, radius: number) -> { Types.CombatTarget },
}

export type Dependencies = {
	now: () -> number,
	allowRequest: (userId: number) -> boolean,
	getLevel: (userId: number) -> number?,
	getPosition: (userId: number) -> Vector3?,
	registryFor: (userId: number) -> TargetLookup,
	schedule: (seconds: number, fn: () -> ()) -> (),
}

-- Lo que el cliente necesita para mostrar el efecto: centro y daño de la primera pulsación.
export type CastOutcome = {
	damage: number,
	center: Vector3,
	hits: number,
}

export type AbilityService = {
	cast: (userId: number, raw: unknown) -> Result.Result<CastOutcome>,
	releasePlayer: (userId: number) -> (),
}

type CastRequest = { abilityId: string, targetId: string? }

local RANGE_TOLERANCE = 4 -- margen en studs para latencia de red
local MULTI_HIT_GAP = 0.25 -- segundos entre golpes de una habilidad multi-golpe
local MAX_ID_LENGTH = 64

local function parseRequest(raw: unknown): Result.Result<CastRequest>
	if type(raw) ~= "table" then
		return Result.err("payload_invalid")
	end
	local data = raw :: { [string]: unknown }
	local abilityId = data.abilityId
	local targetId = data.targetId
	if type(abilityId) ~= "string" or #abilityId == 0 or #abilityId > MAX_ID_LENGTH then
		return Result.err("payload_invalid")
	end
	-- El objetivo es opcional: las habilidades de área no lo necesitan.
	if targetId ~= nil and (type(targetId) ~= "string" or #targetId == 0 or #targetId > MAX_ID_LENGTH) then
		return Result.err("payload_invalid")
	end
	return Result.ok({ abilityId = abilityId, targetId = targetId :: string? })
end

local AbilityService = {}

function AbilityService.new(deps: Dependencies): AbilityService
	-- Estado: instante a partir del cual cada habilidad vuelve a estar disponible, por jugador.
	local readyAtByUser: { [number]: { [string]: number } } = {}

	local function getReadyAt(userId: number, abilityId: string): number
		local perAbility = readyAtByUser[userId]
		if perAbility == nil then
			return 0
		end
		return perAbility[abilityId] or 0
	end

	local function setReadyAt(userId: number, abilityId: string, readyAt: number)
		local perAbility = readyAtByUser[userId]
		if perAbility == nil then
			perAbility = {}
			readyAtByUser[userId] = perAbility
		end
		perAbility[abilityId] = readyAt
	end

	local service = {}

	function service.cast(userId: number, raw: unknown): Result.Result<CastOutcome>
		if not deps.allowRequest(userId) then
			return Result.err("rate_limited")
		end

		local parsed = parseRequest(raw)
		if not parsed.ok then
			return Result.err(parsed.error)
		end
		local request = parsed.value

		local definition = Abilities[request.abilityId]
		if definition == nil then
			return Result.err("unknown_ability")
		end
		local noTargetAllowed = TestConfig.ALLOW_CAST_WITHOUT_TARGET
		if definition.kind ~= "area" and request.targetId == nil and not noTargetAllowed then
			return Result.err("payload_invalid")
		end

		if not TestConfig.NO_LEVELS then
			local level = deps.getLevel(userId)
			if level == nil then
				return Result.err("profile_not_loaded")
			end
			if level < definition.requiredLevel then
				return Result.err("locked")
			end
		end

		local now = deps.now()
		if not TestConfig.NO_COOLDOWNS and now < getReadyAt(userId, definition.id) then
			return Result.err("cooldown")
		end

		local registry = deps.registryFor(userId)
		local origin = deps.getPosition(userId)
		if origin == nil then
			return Result.err("no_character")
		end

		-- Sin objetivo (modo de pruebas): el efecto sale igual, con daño 0.
		if request.targetId == nil and definition.kind ~= "area" then
			setReadyAt(userId, definition.id, now + definition.cooldown)
			return Result.ok({ damage = 0, center = origin, hits = 0 })
		end

		if definition.kind == "area" then
			local targets = registry.near(origin, definition.radius)
			if #targets == 0 then
				if noTargetAllowed then
					setReadyAt(userId, definition.id, now + definition.cooldown)
					return Result.ok({ damage = 0, center = origin, hits = 0 })
				end
				return Result.err("no_targets")
			end
			-- Cooldown antes del efecto: lo que pase después no puede saltárselo.
			setReadyAt(userId, definition.id, now + definition.cooldown)
			for _, target in targets do
				target.takeDamage(definition.damage, userId)
			end
			return Result.ok({ damage = definition.damage, center = origin, hits = #targets })
		end

		local targetId = request.targetId :: string
		local target = registry.get(targetId)
		if target == nil then
			return Result.err("invalid_target")
		end
		local targetPosition = target.getPosition()
		if (targetPosition - origin).Magnitude > definition.range + RANGE_TOLERANCE then
			return Result.err("out_of_range")
		end

		setReadyAt(userId, definition.id, now + definition.cooldown)
		target.takeDamage(definition.damage, userId)

		local hits = 1
		if definition.kind == "multi" then
			-- Los golpes siguientes buscan el objetivo otra vez: si murió antes, ya no suman.
			for index = 2, definition.hits do
				deps.schedule((index - 1) * MULTI_HIT_GAP, function()
					local again = registry.get(targetId)
					if again ~= nil then
						again.takeDamage(definition.damage, userId)
					end
				end)
			end
			hits = definition.hits
		end
		return Result.ok({ damage = definition.damage, center = targetPosition, hits = hits })
	end

	function service.releasePlayer(userId: number)
		readyAtByUser[userId] = nil
	end

	return service
end

return AbilityService

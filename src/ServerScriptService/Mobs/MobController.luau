--!strict
--[[
	Traduce el estado decidido por el servidor en movimiento del Humanoid.
	Es la única parte del mob que toca Instances. Las decisiones (estado, daño, cooldown) son del servidor;
	aquí solo se ejecutan. No está probado en Studio todavía.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Result = require(Shared.Util.Result)
local Types = require(Shared.Types)
local Mob = require(script.Parent.Mob)
local MobScheduler = require(script.Parent.MobScheduler)
local Pathing = require(script.Parent.Pathing)

export type Target = { userId: number, position: Vector3 }

export type Dependencies = {
	now: () -> number,
	findNearestTarget: (position: Vector3, range: number) -> Target?,
	damageTarget: (userId: number, amount: number) -> (),
}

export type Controller = {
	stop: () -> (),
}

local TICK_SECONDS = 0.2
local WANDER_RADIUS = 8
local WANDER_INTERVAL = 4
local RETURN_TIMEOUT = 6 -- segundos: si un mob no llega a casa en este tiempo, se coloca allí
local DEFAULT_ABILITY_COOLDOWN = 8
local CHARGE_SPEED = 42
local CHARGE_SECONDS = 1.0
local CHARGE_MIN_RANGE = 12 -- la embestida solo se usa desde esta distancia
local CHARGE_MULTIPLIER = 1.5
local STUN_SECONDS = 1.2 -- pausa tras una embestida que acierta
local SHOCK_MULTIPLIER = 1.3
local SHOCK_PAUSE = 0.6 -- pausa breve tras la onda de choque

local MobController = {}

function MobController.start(
	model: Model,
	mob: Mob.Mob,
	definition: Types.MobDef,
	home: Vector3,
	deps: Dependencies
): Result.Result<Controller>
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid?
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid == nil or root == nil then
		return Result.err(`{model.Name}: falta Humanoid o HumanoidRootPart`)
	end

	local rng = Random.new()
	local running = true
	local nextWanderAt = 0
	local nextAttackAt = 0
	local returnSince: number? = nil
	local walker = Pathing.new(humanoid, root)
	local wanderGoal: Vector3? = nil

	-- Habilidades especiales (solo jefes con definition.abilities).
	local abilityIndex = 0
	local nextAbilityAt = 0
	local chargeEndsAt = 0
	local chargeUserId = 0
	local chargeGoal: Vector3? = nil
	local stunnedUntil = 0
	local defaultWalkSpeed = humanoid.WalkSpeed

	local function canUseAbility(now: number): boolean
		return now >= nextAbilityAt
	end

	local function nextAbilityName(def: Types.MobDef): string
		local list = def.abilities or {}
		if #list == 0 then
			return ""
		end
		return list[abilityIndex % #list + 1]
	end

	local function advanceAbility()
		abilityIndex += 1
	end

	local function startCharge(target: Target, now: number)
		nextAbilityAt = now + (definition.abilityCooldown or DEFAULT_ABILITY_COOLDOWN)
		advanceAbility()
		chargeEndsAt = now + CHARGE_SECONDS
		chargeUserId = target.userId
		chargeGoal = target.position
		humanoid.WalkSpeed = CHARGE_SPEED
	end

	local function endCharge()
		chargeEndsAt = 0
		chargeGoal = nil
		humanoid.WalkSpeed = defaultWalkSpeed
	end

	local function findChargeGoal(): Vector3?
		local target = deps.findNearestTarget(root.Position, definition.aggroRange * 2)
		if target and target.userId == chargeUserId then
			chargeGoal = target.position
		end
		return chargeGoal
	end

	local function tick()
		local position = root.Position
		mob.setPosition(position)

		local target = deps.findNearestTarget(position, definition.aggroRange)
		local state = mob.update(if target then target.position else nil)
		local now = deps.now()
		if state ~= "Return" then
			returnSince = nil
		end

		if state == "Dead" then
			running = false
			return
		end

		-- Embestida en curso: el mob va a por el objetivo fijado; al chocar, golpea y se queda aturdido.
		if chargeEndsAt > now then
			local chargeTarget = findChargeGoal()
			if chargeTarget then
				humanoid:MoveTo(chargeTarget)
				if (chargeTarget - position).Magnitude <= definition.attackRange + 1 then
					deps.damageTarget(chargeUserId, math.floor(definition.attackDamage * CHARGE_MULTIPLIER))
					endCharge()
					stunnedUntil = now + STUN_SECONDS
				end
			else
				endCharge()
			end
			return
		elseif chargeEndsAt > 0 then
			endCharge()
		end

		if now < stunnedUntil then
			humanoid:MoveTo(position)
			return
		end

		if state == "Chase" and target then
			if canUseAbility(now) and definition.abilities ~= nil and nextAbilityName(definition) == "charge" and (target.position - position).Magnitude >= CHARGE_MIN_RANGE then
				startCharge(target, now)
			else
				Pathing.follow(walker, target.position, now)
			end
		elseif state == "Attack" and target then
			humanoid:MoveTo(position)
			if canUseAbility(now) and definition.abilities ~= nil and nextAbilityName(definition) == "shockwave" then
				nextAbilityAt = now + (definition.abilityCooldown or DEFAULT_ABILITY_COOLDOWN)
				advanceAbility()
				deps.damageTarget(target.userId, math.floor(definition.attackDamage * SHOCK_MULTIPLIER))
				stunnedUntil = now + SHOCK_PAUSE
			elseif now >= nextAttackAt then
				nextAttackAt = now + definition.attackCooldown
				deps.damageTarget(target.userId, definition.attackDamage)
			end
		elseif state == "Return" then
			returnSince = returnSince or now
			if now - returnSince > RETURN_TIMEOUT then
				-- Red de seguridad: si no llega a casa a tiempo, se coloca allí.
				model:PivotTo(CFrame.new(home))
				mob.setPosition(home)
				returnSince = nil
				Pathing.reset(walker)
			else
				Pathing.follow(walker, home, now)
			end
		elseif state == "Patrol" then
			if now >= nextWanderAt then
				nextWanderAt = now + WANDER_INTERVAL
				local offset = Vector3.new(
					rng:NextNumber(-WANDER_RADIUS, WANDER_RADIUS),
					0,
					rng:NextNumber(-WANDER_RADIUS, WANDER_RADIUS)
				)
				wanderGoal = home + offset
			end
			if wanderGoal then
				Pathing.follow(walker, wanderGoal, now)
			end
		end
	end

	-- Sin hilo propio: MobScheduler ejecuta el tick de todos los mobs en un solo bucle.
	MobScheduler.add({
		tick = function()
			local ok, err = pcall(tick)
			if not ok then
				warn(`[MobController] {model.Name}: {err}`)
			end
		end,
		isActive = function()
			return running
		end,
	})

	return Result.ok({
		stop = function()
			running = false
		end,
	})
end

return MobController

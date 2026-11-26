--!strict
--[[
	Entidad de mob en el servidor. Guarda vida y estado, y avisa una sola vez al morir.
	No mueve Instances: el controlador visual (pendiente) lee el estado y actúa sobre el Humanoid.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local MobStateMachine = require(script.Parent.MobStateMachine)
local DomainEvents = require(script.Parent.Parent.Events.DomainEvents)

export type Mob = Types.CombatTarget & {
	instanceId: string,
	getHealth: () -> number,
	getState: () -> MobStateMachine.MobState,
	setPosition: (position: Vector3) -> (),
	update: (targetPosition: Vector3?) -> MobStateMachine.MobState,
}

local Mob = {}

function Mob.new(
	instanceId: string,
	definition: Types.MobDef,
	home: Vector3,
	onKilled: (event: DomainEvents.MobKilledEvent) -> (),
	onHealthChanged: ((health: number) -> ())?
): Mob
	local state: MobStateMachine.MobState = "Patrol"
	local health = definition.maxHealth
	local position = home
	local damageByUser: { [number]: number } = {}

	local mob = {}
	mob.instanceId = instanceId

	function mob.getPosition(): Vector3
		return position
	end

	function mob.getHealth(): number
		return health
	end

	function mob.getState(): MobStateMachine.MobState
		return state
	end

	function mob.setPosition(newPosition: Vector3)
		position = newPosition
	end

	function mob.takeDamage(amount: number, sourceUserId: number)
		if state == "Dead" or amount <= 0 then
			return
		end

		-- Solo cuenta el daño que realmente quitó vida: el exceso del golpe final no suma.
		local dealt = math.min(amount, health)
		damageByUser[sourceUserId] = (damageByUser[sourceUserId] or 0) + dealt
		health = math.max(0, health - amount)
		if onHealthChanged then
			onHealthChanged(health)
		end
		if health > 0 then
			return
		end

		state = "Dead"
		local contributorIds = {}
		local damageReport: { [number]: number } = {}
		for userId, dealt in damageByUser do
			table.insert(contributorIds, userId)
			damageReport[userId] = dealt
		end
		onKilled({
			instanceId = instanceId,
			mobDefId = definition.id,
			killerUserId = sourceUserId,
			contributorUserIds = contributorIds,
			damageByUserId = damageReport,
		})
	end

	function mob.update(targetPosition: Vector3?): MobStateMachine.MobState
		if state == "Dead" then
			return state
		end

		-- Todas las distancias son horizontales: la altura del modelo no debe impedir llegar a casa.
		local distanceToTarget: number? = nil
		if targetPosition ~= nil then
			local delta = targetPosition - position
			distanceToTarget = Vector2.new(delta.X, delta.Z).Magnitude
		end
		local homeDelta = position - home

		state = MobStateMachine.nextState(state, {
			health = health,
			distanceFromHome = Vector2.new(homeDelta.X, homeDelta.Z).Magnitude,
			distanceToTarget = distanceToTarget,
			aggroRange = definition.aggroRange,
			attackRange = definition.attackRange,
			leashRange = definition.leashRange,
		})
		return state
	end

	return mob :: Mob
end

return Mob

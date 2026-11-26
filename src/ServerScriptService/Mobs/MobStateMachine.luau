--!strict
--[[
	Máquina de estados de un mob. Es pura: no conoce Instances ni el tiempo.
	Recibe la percepción del mundo y devuelve el siguiente estado.
	Por eso se puede probar sin Studio.

	Regla de diseño: mientras vuelve a casa (Return) un mob no vuelve a detectar al jugador.
	Evita que el aggro lo haga oscilar entre Return y Chase en la frontera del rango.
]]

export type MobState = "Patrol" | "Chase" | "Attack" | "Return" | "Dead"

export type Perception = {
	health: number,
	distanceFromHome: number,
	distanceToTarget: number?, -- nil si no hay objetivo válido
	aggroRange: number,
	attackRange: number,
	leashRange: number,
}

local ARRIVAL_THRESHOLD = 1 -- studs

local MobStateMachine = {}

function MobStateMachine.nextState(current: MobState, perception: Perception): MobState
	if current == "Dead" or perception.health <= 0 then
		return "Dead"
	end

	if current == "Return" then
		if perception.distanceFromHome <= ARRIVAL_THRESHOLD then
			return "Patrol"
		end
		return "Return"
	end

	if perception.distanceFromHome > perception.leashRange then
		return "Return"
	end

	local distance = perception.distanceToTarget
	if distance == nil or distance > perception.aggroRange then
		if current == "Patrol" then
			return "Patrol"
		end
		return "Return"
	end

	if distance <= perception.attackRange then
		return "Attack"
	end
	return "Chase"
end

return MobStateMachine

--!strict
--[[
	Temporizador de pociones. Reglas puras, sin Roblox (se prueban en PotionTimer.spec).
	- Hay una poción activa a la vez.
	- Otra poción del MISMO tipo suma su duración a la activa.
	- Una poción de OTRO tipo espera en cola hasta que termine la activa.
	- Al terminar, la siguiente de la cola empieza donde acabó la anterior, no al usarla.
]]

export type Potion = { kind: string, multiplier: number, durationSeconds: number }
export type Active = { kind: string, multiplier: number, endsAt: number }
export type State = { active: Active?, queue: { Potion } }

local PotionTimer = {}

function PotionTimer.new(): State
	return { active = nil, queue = {} }
end

-- Quita lo que ya caducó y activa la siguiente de la cola, cuantas veces haga falta.
function PotionTimer.advance(state: State, now: number)
	while state.active ~= nil and now >= state.active.endsAt do
		local ended = state.active.endsAt
		local nextPotion = table.remove(state.queue, 1)
		if nextPotion == nil then
			state.active = nil
		else
			state.active = {
				kind = nextPotion.kind,
				multiplier = nextPotion.multiplier,
				endsAt = ended + nextPotion.durationSeconds,
			}
		end
	end
end

function PotionTimer.use(state: State, now: number, potion: Potion)
	PotionTimer.advance(state, now)
	if state.active == nil then
		state.active = { kind = potion.kind, multiplier = potion.multiplier, endsAt = now + potion.durationSeconds }
	elseif state.active.kind == potion.kind then
		state.active.endsAt += potion.durationSeconds
	else
		table.insert(state.queue, potion)
	end
end

-- Multiplicador vigente. 1 si no hay ninguna poción activa.
function PotionTimer.multiplier(state: State, now: number): number
	PotionTimer.advance(state, now)
	if state.active == nil then
		return 1
	end
	return state.active.multiplier
end

-- Momento en que termina la poción activa, o nil si no hay ninguna.
function PotionTimer.endsAt(state: State, now: number): number?
	PotionTimer.advance(state, now)
	if state.active == nil then
		return nil
	end
	return state.active.endsAt
end

function PotionTimer.queued(state: State): number
	return #state.queue
end

return table.freeze(PotionTimer)

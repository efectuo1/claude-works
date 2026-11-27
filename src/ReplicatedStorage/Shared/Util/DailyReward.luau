--!strict
--[[
	Regalo diario y racha. Reglas puras (sin Roblox), se prueban en DailyReward.spec.
	- Un premio por día (día = 86400 s, en UTC). Solo se reclama una vez al día.
	- Si se reclama el día siguiente al anterior, la racha sube; si se salta un día, vuelve a 1.
	- Los premios van en un ciclo de 7 días: el día 8 de racha vuelve al premio del día 1.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Shared.Util.Result)

export type Reward = { gold: number?, gems: number?, itemId: string?, quantity: number? }
export type State = { lastDay: number, streak: number }
export type Status = { claimedToday: boolean, streak: number, nextStreak: number, reward: Reward, cycleDay: number }

local DailyReward = {}

DailyReward.CYCLE = 7
DailyReward.SECONDS_PER_DAY = 86400

-- Premio de cada día del ciclo (índice = día dentro del ciclo, 1..7).
local DAYS: { Reward } = {
	{ gold = 100 },
	{ gems = 2 },
	{ itemId = "xp_potion_10", quantity = 1 },
	{ gold = 300 },
	{ itemId = "llave_dorada", quantity = 1 },
	{ gems = 5 },
	{ itemId = "xp_potion_15", quantity = 2, gems = 10 },
}

function DailyReward.dayOf(unixSeconds: number): number
	return math.floor(unixSeconds / DailyReward.SECONDS_PER_DAY)
end

function DailyReward.empty(): State
	return { lastDay = 0, streak = 0 }
end

-- Qué pasa hoy: si ya se reclamó, cuánta racha hay y qué premio toca.
function DailyReward.status(state: State, today: number): Status
	local claimedToday = state.lastDay == today
	local continuing = state.lastDay == today - 1
	-- Si hoy no está reclamado, la racha que se obtendría al reclamar.
	local nextStreak = if claimedToday then state.streak elseif continuing then state.streak + 1 else 1
	local cycleDay = ((nextStreak - 1) % DailyReward.CYCLE) + 1
	return {
		claimedToday = claimedToday,
		streak = state.streak,
		nextStreak = nextStreak,
		reward = DAYS[cycleDay],
		cycleDay = cycleDay,
	}
end

-- Reclama el premio de hoy. Devuelve el estado nuevo y el premio, o un error si ya se reclamó.
function DailyReward.claim(state: State, today: number): Result.Result<{ state: State, reward: Reward, streak: number }>
	local status = DailyReward.status(state, today)
	if status.claimedToday then
		return Result.err("ya_reclamado_hoy")
	end
	local nextState: State = { lastDay = today, streak = status.nextStreak }
	return Result.ok({ state = nextState, reward = status.reward, streak = status.nextStreak })
end

function DailyReward.days(): { Reward }
	return DAYS
end

return table.freeze(DailyReward)

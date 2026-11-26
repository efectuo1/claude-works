--!strict
--[[
	Reglas de recompensa: cuánto oro y gemas da cada fuente según el rango del jugador,
	y cuándo puede subir de rango. Lógica pura: el azar entra por parámetro (Random),
	así que se prueba sin Studio.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Economy = require(ReplicatedStorage.Shared.Definitions.Economy)
local Ranks = require(ReplicatedStorage.Shared.Definitions.Ranks)
local Result = require(ReplicatedStorage.Shared.Util.Result)
local Perks = require(ReplicatedStorage.Shared.Util.Perks)

export type Grant = { gold: number, gems: number }
export type RankDef = Ranks.RankDef

local Rewards = {}

local function round(n: number): number
	return math.floor(n + 0.5)
end

-- Posición del rango en la lista. Un id desconocido se trata como el primero (novato).
function Rewards.rankIndex(rankId: string): number
	for index, rank in Ranks do
		if rank.id == rankId then
			return index
		end
	end
	return 1
end

function Rewards.rankOrDefault(rankId: string): RankDef
	return Ranks[Rewards.rankIndex(rankId)]
end

function Rewards.nextRank(rankId: string): RankDef?
	return Ranks[Rewards.rankIndex(rankId) + 1]
end

-- Oro que suelta un mob antes de repartirlo: una sola tirada por muerte. Un mob sin datos no da nada.
function Rewards.rollMobPool(mobId: string, rng: Random): number
	local entry: Economy.MobReward? = Economy.MOBS[mobId]
	if entry == nil then
		return 0
	end
	return rng:NextNumber(entry.goldMin, entry.goldMax)
end

-- Parte de un jugador en una muerte. Con pool (el oro ya tirado), su oro es su participación
-- del pool escalada por su rango. Sin pool, tira su propio oro, como antes.
-- share: participación del jugador (1 si lo mató solo). Escala también la probabilidad de gema.
-- perks: efectos de sus pases (oro x2, gemas x2). Opcional.
function Rewards.rollMob(mobId: string, rank: RankDef, rng: Random, share: number?, pool: number?, perks: Perks.Perks?): Grant
	local entry: Economy.MobReward? = Economy.MOBS[mobId]
	if entry == nil then
		return { gold = 0, gems = 0 }
	end
	local part = share or 1
	local boost = perks or Perks.NONE
	local gold
	if pool ~= nil then
		gold = round(pool * rank.goldMult * part * boost.goldMult)
	else
		gold = round(rng:NextNumber(entry.goldMin, entry.goldMax) * rank.goldMult * boost.goldMult)
	end
	local gemChance = entry.gemChance * rank.gemMult * part * boost.gemMult
	local gems = if rng:NextNumber() < gemChance then 1 else 0
	return { gold = gold, gems = gems }
end

-- Jefe: oro en rango y al menos una gema garantizada.
function Rewards.rollBoss(rank: RankDef, rng: Random): Grant
	local boss = Economy.BOSS
	local gold = round(rng:NextNumber(boss.goldMin, boss.goldMax) * rank.goldMult)
	local gems = math.max(boss.gems, math.floor(boss.gems * rank.gemMult))
	return { gold = gold, gems = gems }
end

-- Misión: recompensa fija multiplicada por el rango. Una misión sin datos no da nada.
function Rewards.questGrant(questId: string, rank: RankDef): Grant
	local reward: Economy.QuestReward? = Economy.QUESTS[questId]
	if reward == nil then
		return { gold = 0, gems = 0 }
	end
	return { gold = round(reward.gold * rank.goldMult), gems = math.floor(reward.gems * rank.gemMult) }
end

export type Direction = "goldToGems" | "gemsToGold"
export type Balance = { gold: number, gems: number }
local MAX_EXCHANGE = 1000000

-- Cambio oro <-> gemas a la tasa de Economy.EXCHANGE. Devuelve el saldo nuevo; no toca el perfil.
function Rewards.exchange(direction: string, amount: number, balance: Balance): Result.Result<Balance>
	if amount ~= math.floor(amount) or amount < 1 or amount > MAX_EXCHANGE then
		return Result.err("cantidad_invalida")
	end
	local rate = Economy.EXCHANGE.goldPerGem
	if direction == "goldToGems" then
		local cost = amount * rate
		if balance.gold < cost then
			return Result.err("oro_insuficiente")
		end
		return Result.ok({ gold = balance.gold - cost, gems = balance.gems + amount })
	elseif direction == "gemsToGold" then
		if balance.gems < amount then
			return Result.err("gemas_insuficientes")
		end
		return Result.ok({ gold = balance.gold + amount * rate, gems = balance.gems - amount })
	end
	return Result.err("direccion_invalida")
end

-- Solo valida: no descuenta nada. Quien aplica el coste es el monedero.
function Rewards.canRankUp(level: number, gold: number, gems: number, rankId: string): Result.Result<RankDef>
	local target = Rewards.nextRank(rankId)
	if target == nil then
		return Result.err("rango_maximo")
	end
	if level < target.minLevel then
		return Result.err("nivel_insuficiente")
	end
	if gold < target.cost.gold then
		return Result.err("oro_insuficiente")
	end
	if gems < target.cost.gems then
		return Result.err("gemas_insuficientes")
	end
	return Result.ok(target)
end

return Rewards

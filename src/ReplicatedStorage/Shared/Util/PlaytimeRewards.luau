--!strict
--[[
	Premios por tiempo de juego seguido. Reglas puras, se prueban en PlaytimeRewards.spec.
	- Cuenta el tiempo desde que entras al servidor; si sales, vuelve a empezar.
	- Cada hito se reclama una vez por sesión. Más tiempo = mejor premio.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Shared.Util.Result)

export type Tier = { minutes: number, gold: number?, gems: number?, itemId: string?, quantity: number? }

local PlaytimeRewards = {}

local TIERS: { Tier } = {
	{ minutes = 15, gold = 300 },
	{ minutes = 30, gems = 3 },
	{ minutes = 60, gold = 800, itemId = "llave_dorada", quantity = 1 },
	{ minutes = 90, gems = 8, itemId = "xp_potion_15", quantity = 2 },
	{ minutes = 120, gems = 15, itemId = "llave_brasa", quantity = 1 },
}

function PlaytimeRewards.tiers(): { Tier }
	return TIERS
end

-- Índices de los hitos ya cumplidos (alcanzados por el tiempo) y sin reclamar.
function PlaytimeRewards.ready(elapsedSeconds: number, claimed: { [number]: boolean }): { number }
	local list = {}
	for index, tier in TIERS do
		if elapsedSeconds >= tier.minutes * 60 and not claimed[index] then
			table.insert(list, index)
		end
	end
	return list
end

-- Reclama un hito. Error si no se ha alcanzado o ya se reclamó en esta sesión.
function PlaytimeRewards.claim(index: number, elapsedSeconds: number, claimed: { [number]: boolean }): Result.Result<Tier>
	local tier = TIERS[index]
	if tier == nil then
		return Result.err("hito_desconocido")
	end
	if claimed[index] then
		return Result.err("ya_reclamado")
	end
	if elapsedSeconds < tier.minutes * 60 then
		return Result.err("aun_no_disponible")
	end
	claimed[index] = true
	return Result.ok(tier)
end

return table.freeze(PlaytimeRewards)

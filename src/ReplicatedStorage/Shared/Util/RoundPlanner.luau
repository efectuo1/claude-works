--!strict
--[[
	Planificador de rondas (modalidad de oleadas): qué mobs salen en cada ronda.
	Puro: no toca Roblox. La ronda sube en cantidad y cada 5 rondas aparece un mob fuerte.
	Los ids de mob deben existir en Definitions/Mobs (lo comprueba el test de la tabla real).
]]

local Result = require(script.Parent.Result)

local RoundPlanner = {}

local BASE_MOBS = { "ember_sprite", "ember_wolf" }
local STRONG_MOB = "ash_brute"
local STRONG_EVERY = 5 -- cada cuántas rondas aparece el mob fuerte
local FIRST_ROUND_SIZE = 4
local GROWTH_PER_ROUND = 2
local MAX_BASE_MOBS = 12 -- tope de mobs normales por ronda, para que no crezca sin límite

-- Lista de ids de mob para la ronda indicada (empieza en 1).
function RoundPlanner.plan(round: number): Result.Result<{ string }>
	if round < 1 or round % 1 ~= 0 then
		return Result.err("la ronda debe ser un entero desde 1")
	end
	local count = math.min(MAX_BASE_MOBS, FIRST_ROUND_SIZE + (round - 1) * GROWTH_PER_ROUND)
	local list: { string } = {}
	for index = 1, count do
		table.insert(list, BASE_MOBS[(index - 1) % #BASE_MOBS + 1])
	end
	if round % STRONG_EVERY == 0 then
		table.insert(list, STRONG_MOB)
	end
	return Result.ok(list)
end

-- El mob que hace de jefe en las rondas múltiplo de 5. Las oleadas de jefe lo cambian por su jefe.
function RoundPlanner.strongMob(): string
	return STRONG_MOB
end

-- Todos los ids que puede producir el planificador (para validarlos contra las definiciones).
function RoundPlanner.possibleMobIds(): { string }
	local ids = table.clone(BASE_MOBS)
	table.insert(ids, STRONG_MOB)
	return ids
end

return table.freeze(RoundPlanner)

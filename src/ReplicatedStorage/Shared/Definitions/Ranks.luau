--!strict
--[[
	Rangos como datos, en orden. Subir de rango exige nivel mínimo y pagar un coste.
	Cada rango multiplica oro, gemas y suerte de drop. Subir es decisión del jugador.
]]

export type Cost = { gold: number, gems: number }
export type RankDef = {
	id: string,
	name: string,
	minLevel: number,
	cost: Cost,
	goldMult: number,
	gemMult: number,
	luck: number, -- +suerte de drop (0.05 = +5 %), para el DropService
}

local RANKS: { RankDef } = {
	{ id = "novato", name = "Novato", minLevel = 1, cost = { gold = 0, gems = 0 }, goldMult = 1, gemMult = 1, luck = 0 },
	{ id = "aprendiz", name = "Aprendiz", minLevel = 10, cost = { gold = 500, gems = 0 }, goldMult = 1.15, gemMult = 1.1, luck = 0.05 },
	{ id = "guerrero", name = "Guerrero", minLevel = 20, cost = { gold = 2000, gems = 10 }, goldMult = 1.35, gemMult = 1.25, luck = 0.1 },
	{ id = "maestro", name = "Maestro", minLevel = 35, cost = { gold = 8000, gems = 40 }, goldMult = 1.6, gemMult = 1.5, luck = 0.18 },
	{ id = "leyenda", name = "Leyenda", minLevel = 50, cost = { gold = 25000, gems = 120 }, goldMult = 2, gemMult = 2, luck = 0.3 },
}

return table.freeze(RANKS)

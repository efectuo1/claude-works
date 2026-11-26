--!strict
--[[
	Economía como datos. Oro: común, sube con la dificultad de la fuente.
	Gemas: escasas. Los mobs las sueltan con una probabilidad, los élite un poco más, y los
	jefes siempre dan al menos una. Valores provisionales hasta la pasada de balance.
]]

local Economy = {}

export type MobReward = { goldMin: number, goldMax: number, gemChance: number }
export type QuestReward = { gold: number, gems: number }
export type BossReward = { goldMin: number, goldMax: number, gems: number }

-- Mobs: rango de oro y probabilidad base de gema por persona que contribuye.
Economy.MOBS = {
	ember_wolf = { goldMin = 8, goldMax = 14, gemChance = 0.02 },
	ember_sprite = { goldMin = 5, goldMax = 9, gemChance = 0.01 },
	ash_brute = { goldMin = 25, goldMax = 40, gemChance = 0.10 },
	-- Jefes de oleadas: su gema segura es aparte (WaveService).
	ash_captain = { goldMin = 60, goldMax = 90, gemChance = 0.10 },
	ember_tyrant = { goldMin = 150, goldMax = 220, gemChance = 0.10 },
}

-- Misiones: recompensa fija (antes de multiplicar por el rango).
Economy.QUESTS = {
	first_hunt = { gold = 150, gems = 1 },
}

-- Jefes: oro en rango y gemas garantizadas (mínimo).
Economy.BOSS = { goldMin = 200, goldMax = 400, gems = 1 }

-- Cambio oro <-> gemas en la tienda: cuánto oro vale 1 gema, en las dos direcciones.
-- 200 coincide con los rangos: 2000 oro = 10 gemas, 8000 oro = 40 gemas.
Economy.EXCHANGE = { goldPerGem = 200 }

return table.freeze(Economy)

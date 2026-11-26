--!strict
--[[
	Pociones: objetos del inventario que multiplican el XP durante un tiempo.
	Se usan desde la mochila (USAR). Se compran con gemas en la tienda.
	Duración en segundos: 10 o 15 minutos. El tipo "xp" es el único por ahora (ver docs/DISENO_MODALIDADES.md).
	gemPrice es PROVISIONAL: se ajusta en la pasada de balance.
]]

export type Potion = {
	id: string,
	displayName: string,
	kind: string,
	multiplier: number,
	durationSeconds: number,
	gemPrice: number,
}

local Potions: { [string]: Potion } = {
	xp_potion_10 = { id = "xp_potion_10", displayName = "Poción de XP (10 min)", kind = "xp", multiplier = 2, durationSeconds = 600, gemPrice = 40 },
	xp_potion_15 = { id = "xp_potion_15", displayName = "Poción de XP (15 min)", kind = "xp", multiplier = 2, durationSeconds = 900, gemPrice = 55 },
}

return table.freeze(Potions)

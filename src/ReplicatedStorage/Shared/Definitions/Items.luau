--!strict
-- Definiciones de ítems. La rareza vive aquí como dato: el loot y la UI la leen de esta tabla.
-- Valores provisionales: se ajustan en la pasada de balance.
local Types = require(script.Parent.Parent.Types)

local Items: { [string]: Types.ItemDef } = {
	ember_shard = { id = "ember_shard", displayName = "Fragmento de Brasa", rarity = "Common", maxStack = 999 },
	wolf_pelt = { id = "wolf_pelt", displayName = "Piel de Lobo", rarity = "Common", maxStack = 999 },
	stone_core = { id = "stone_core", displayName = "Núcleo de Piedra", rarity = "Common", maxStack = 99 },
	spark_essence = { id = "spark_essence", displayName = "Esencia Chispa", rarity = "Rare", maxStack = 99 },
	fruit_ember_moon = { id = "fruit_ember_moon", displayName = "Fruta Luna de Brasa", rarity = "Epic", maxStack = 1 },
}

return table.freeze(Items)

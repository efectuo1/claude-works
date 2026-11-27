--!strict
-- Definiciones de ítems. La rareza y la categoría viven aquí como datos: el loot, el inventario y la UI las leen de esta tabla.
-- Oro y gemas no están aquí: son monedas de la cartera, no objetos de la mochila.
-- Valores provisionales: se ajustan en la pasada de balance.
local Types = require(script.Parent.Parent.Types)

local Items: { [string]: Types.ItemDef } = {
	-- Materiales: lo que sueltan los mobs.
	ember_shard = { id = "ember_shard", displayName = "Fragmento de Brasa", rarity = "Common", category = "material", maxStack = 999 },
	wolf_pelt = { id = "wolf_pelt", displayName = "Piel de Lobo", rarity = "Common", category = "material", maxStack = 999 },
	stone_core = { id = "stone_core", displayName = "Núcleo de Piedra", rarity = "Common", category = "material", maxStack = 99 },
	spark_essence = { id = "spark_essence", displayName = "Esencia Chispa", rarity = "Rare", category = "material", maxStack = 99 },

	-- Frutas: se usarán con el sistema de frutas (pendiente).
	fruit_ember_moon = { id = "fruit_ember_moon", displayName = "Fruta Luna de Brasa", rarity = "Epic", category = "fruta", maxStack = 1 },

	-- Pociones: se usan desde el inventario.
	xp_potion_10 = { id = "xp_potion_10", displayName = "Poción de XP (10 min)", rarity = "Rare", category = "pocion", maxStack = 99 },
	xp_potion_15 = { id = "xp_potion_15", displayName = "Poción de XP (15 min)", rarity = "Rare", category = "pocion", maxStack = 99 },

	-- Llaves: abren cofres y accesos (todavía sin uso; se entregan por premios).
	llave_dorada = { id = "llave_dorada", displayName = "Llave Dorada", rarity = "Rare", category = "llave", maxStack = 20 },
	llave_brasa = { id = "llave_brasa", displayName = "Llave de Brasa", rarity = "Epic", category = "llave", maxStack = 5 },

	-- Accesorios: se equipan (pendiente de la ranura de equipo).
	anillo_brasa = { id = "anillo_brasa", displayName = "Anillo de Brasa", rarity = "Rare", category = "accesorio", maxStack = 1 },
	collar_lobo = { id = "collar_lobo", displayName = "Collar de Lobo", rarity = "Common", category = "accesorio", maxStack = 1 },
}

return table.freeze(Items)

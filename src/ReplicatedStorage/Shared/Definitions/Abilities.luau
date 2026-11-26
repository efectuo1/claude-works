--!strict
-- Datos puros de habilidades. Añadir una habilidad = añadir una entrada aquí.
-- Inspiración: frutas del diablo (One Piece) y jutsus (Naruto). Nombres y efectos son propios.
-- kind:
--   single  -> un objetivo dentro de range.
--   multi   -> un objetivo; "hits" golpes, separados por una pausa corta.
--   area    -> todos los enemigos dentro de radius del lanzador (no necesita objetivo).
local Types = require(script.Parent.Parent.Types)

local Abilities: { [string]: Types.AbilityDef } = {
	punch_magma = {
		id = "punch_magma",
		displayName = "Puño de Magma",
		cooldown = 2,
		range = 8,
		damage = 40,
		requiredLevel = 1,
		rarity = "Common",
		kind = "single",
		radius = 0,
		hits = 1,
	},
	ember_lance = {
		id = "ember_lance",
		displayName = "Lanza de Brasa",
		cooldown = 3,
		range = 18,
		damage = 45,
		requiredLevel = 10,
		rarity = "Rare",
		kind = "single",
		radius = 0,
		hits = 1,
	},
	ash_storm = {
		id = "ash_storm",
		displayName = "Tormenta de Ceniza",
		cooldown = 6,
		range = 12, -- en área, range y radius coinciden: el alcance desde el lanzador
		damage = 30,
		requiredLevel = 10,
		rarity = "Rare",
		kind = "area",
		radius = 12,
		hits = 1,
	},
	smoke_clone = {
		id = "smoke_clone",
		displayName = "Clon de Humo",
		cooldown = 5,
		range = 14,
		damage = 18,
		requiredLevel = 25,
		rarity = "Epic",
		kind = "multi",
		radius = 0,
		hits = 3,
	},
}

return table.freeze(Abilities)

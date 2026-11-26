--!strict
-- Tablas de drop por mob. Los pesos son relativos; se validan al arrancar el servidor.
local Types = require(script.Parent.Parent.Types)

local DropTables: { [string]: Types.DropTable } = {
	ember_wolf = {
		entries = {
			{ itemId = "ember_shard", weight = 70, minQuantity = 1, maxQuantity = 3 },
			{ itemId = "wolf_pelt", weight = 25, minQuantity = 1, maxQuantity = 1 },
			{ itemId = "fruit_ember_moon", weight = 5, minQuantity = 1, maxQuantity = 1 },
		},
	},
	ember_sprite = {
		entries = {
			{ itemId = "ember_shard", weight = 90, minQuantity = 1, maxQuantity = 2 },
			{ itemId = "spark_essence", weight = 10, minQuantity = 1, maxQuantity = 1 },
		},
	},
	ash_brute = {
		entries = {
			{ itemId = "ember_shard", weight = 60, minQuantity = 2, maxQuantity = 4 },
			{ itemId = "stone_core", weight = 40, minQuantity = 1, maxQuantity = 1 },
		},
	},
	ash_captain = {
		entries = {
			{ itemId = "ember_shard", weight = 50, minQuantity = 5, maxQuantity = 8 },
			{ itemId = "stone_core", weight = 50, minQuantity = 1, maxQuantity = 2 },
		},
	},
	ember_tyrant = {
		entries = {
			{ itemId = "ember_shard", weight = 40, minQuantity = 10, maxQuantity = 15 },
			{ itemId = "stone_core", weight = 60, minQuantity = 2, maxQuantity = 3 },
		},
	},
}

return table.freeze(DropTables)

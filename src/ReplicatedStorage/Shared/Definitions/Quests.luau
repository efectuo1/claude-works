--!strict
-- Datos de misiones. Una misión = un objetivo y una recompensa.
local Types = require(script.Parent.Parent.Types)

local Quests: { [string]: Types.QuestDef } = {
	first_hunt = {
		id = "first_hunt",
		title = "Primera caza",
		objective = { kind = "killMob", mobDefId = "ember_wolf", count = 5 },
		reward = { itemId = "ember_shard", quantity = 3 },
	},
	ember_collector = {
		id = "ember_collector",
		title = "Brasas para el herrero",
		objective = { kind = "collectItem", itemId = "ember_shard", count = 10 },
		reward = { itemId = "stone_core", quantity = 1 },
	},
}

return table.freeze(Quests)

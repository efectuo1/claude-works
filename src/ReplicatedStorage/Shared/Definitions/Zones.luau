--!strict
-- Zonas como datos. Para añadir una zona: crear su carpeta en workspace.Zones con un Folder "Spawns" y añadir la entrada aquí.
local Types = require(script.Parent.Parent.Types)

local Zones: { [string]: Types.ZoneDef } = {
	starter_ember_fields = {
		id = "starter_ember_fields",
		displayName = "Campos de Brasa",
		spawns = {
			{ mobDefId = "ember_wolf", spawnPointName = "Wolf_1", respawnSeconds = 20 },
			{ mobDefId = "ember_wolf", spawnPointName = "Wolf_2", respawnSeconds = 20 },
			{ mobDefId = "ember_wolf", spawnPointName = "Wolf_3", respawnSeconds = 20 },
			{ mobDefId = "ember_sprite", spawnPointName = "Sprite_1", respawnSeconds = 15 },
			{ mobDefId = "ember_sprite", spawnPointName = "Sprite_2", respawnSeconds = 15 },
			{ mobDefId = "ash_brute", spawnPointName = "Brute_1", respawnSeconds = 45 },
		},
	},
}

return table.freeze(Zones)

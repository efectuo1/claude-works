--!strict
-- Datos de mobs. Rangos en studs, tiempos en segundos. Los ids enlazan con DropTables y con las plantillas en ServerStorage.
local Types = require(script.Parent.Parent.Types)

local Mobs: { [string]: Types.MobDef } = {
	ember_wolf = {
		id = "ember_wolf",
		displayName = "Lobo de Brasa",
		maxHealth = 100,
		aggroRange = 30,
		attackRange = 6,
		leashRange = 60,
		attackDamage = 8,
		attackCooldown = 1.2,
		dropTableId = "ember_wolf",
		xp = 15,
	},
	ember_sprite = {
		id = "ember_sprite",
		displayName = "Espíritu de Brasa",
		maxHealth = 60,
		aggroRange = 20,
		attackRange = 10,
		leashRange = 40,
		attackDamage = 5,
		attackCooldown = 1.5,
		dropTableId = "ember_sprite",
		xp = 10,
	},
	ash_brute = {
		id = "ash_brute",
		displayName = "Bruto de Ceniza",
		maxHealth = 250,
		aggroRange = 18,
		attackRange = 5,
		leashRange = 35,
		attackDamage = 20,
		attackCooldown = 2,
		dropTableId = "ash_brute",
		xp = 40,
	},
	-- Jefes de la modalidad de oleadas. Reutilizan el modelo del Bruto hasta tener los suyos en Studio.
	ash_captain = {
		id = "ash_captain",
		displayName = "Capitán de Ceniza",
		maxHealth = 900,
		aggroRange = 30,
		attackRange = 6,
		leashRange = 50,
		attackDamage = 28,
		attackCooldown = 1.8,
		dropTableId = "ash_captain",
		xp = 150,
		templateId = "ash_brute",
		abilities = { "charge", "shockwave" },
		abilityCooldown = 7,
	},
	ember_tyrant = {
		id = "ember_tyrant",
		displayName = "Tirano de Brasa",
		maxHealth = 3000,
		aggroRange = 40,
		attackRange = 7,
		leashRange = 60,
		attackDamage = 45,
		attackCooldown = 2.2,
		dropTableId = "ember_tyrant",
		xp = 600,
		templateId = "ash_brute",
	},
}

return table.freeze(Mobs)

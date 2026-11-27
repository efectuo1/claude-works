--!strict
-- Pruebas del validador de contenido. Cada prueba parte de un contenido válido nuevo y lo rompe una vez.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentValidator = require(ReplicatedStorage.Shared.Definitions.ContentValidator)
local TestHarness = require(script.Parent.TestHarness)

local function validContent(): ContentValidator.Content
	return {
		items = {
			a = { id = "a", displayName = "A", rarity = "Common", category = "material", maxStack = 10 },
		},
		abilities = {},
		dropTables = {
			t = { entries = { { itemId = "a", weight = 1, minQuantity = 1, maxQuantity = 1 } } },
		},
		mobs = {
			m = {
				id = "m",
				displayName = "M",
				maxHealth = 1,
				aggroRange = 1,
				attackRange = 1,
				leashRange = 1,
				attackDamage = 1,
				attackCooldown = 1,
				dropTableId = "t",
			},
		},
		zones = {
			z = {
				id = "z",
				displayName = "Z",
				spawns = { { mobDefId = "m", spawnPointName = "P", respawnSeconds = 1 } },
			},
		},
		quests = {
			q = {
				id = "q",
				title = "Q",
				objective = { kind = "killMob", mobDefId = "m", count = 1 },
				reward = { itemId = "a", quantity = 1 },
			},
		},
	}
end

local function expectRejected(content: ContentValidator.Content): boolean
	return not ContentValidator.validate(content).ok
end

return {
	run = function(): boolean
		return TestHarness.run("ContentValidator", {
			["contenido base es válido"] = function()
				TestHarness.expect(ContentValidator.validate(validContent()).ok, "el contenido base debería ser válido")
			end,

			["habilidad de jefe desconocida se rechaza"] = function()
				local content = validContent()
				content.mobs.m.abilities = { "salto" }
				content.mobs.m.abilityCooldown = 5
				TestHarness.expect(expectRejected(content), "debería rechazar la habilidad desconocida")
			end,

			["habilidades sin enfriamiento se rechazan"] = function()
				local content = validContent()
				content.mobs.m.abilities = { "charge" }
				TestHarness.expect(expectRejected(content), "debería rechazar habilidades sin abilityCooldown")
			end,

			["habilidades conocidas con enfriamiento son válidas"] = function()
				local content = validContent()
				content.mobs.m.abilities = { "charge", "shockwave" }
				content.mobs.m.abilityCooldown = 7
				TestHarness.expect(ContentValidator.validate(content).ok, "las habilidades conocidas deben ser válidas")
			end,

			["drop con ítem desconocido se rechaza"] = function()
				local content = validContent()
				content.dropTables.t.entries[1].itemId = "fantasma"
				TestHarness.expect(expectRejected(content), "debería rechazar el ítem desconocido")
			end,

			["mob con tabla de drop desconocida se rechaza"] = function()
				local content = validContent()
				content.mobs.m.dropTableId = "no_existe"
				TestHarness.expect(expectRejected(content), "debería rechazar la tabla desconocida")
			end,

			["spawn de mob desconocido se rechaza"] = function()
				local content = validContent()
				content.zones.z.spawns[1].mobDefId = "no_existe"
				TestHarness.expect(expectRejected(content), "debería rechazar el mob desconocido")
			end,

			["recompensa de misión con ítem desconocido se rechaza"] = function()
				local content = validContent()
				content.quests.q.reward.itemId = "no_existe"
				TestHarness.expect(expectRejected(content), "debería rechazar la recompensa desconocida")
			end,

			["objetivo collectItem con ítem desconocido se rechaza"] = function()
				local content = validContent()
				content.quests.q.objective = { kind = "collectItem", itemId = "no_existe", count = 1 }
				TestHarness.expect(expectRejected(content), "debería rechazar el objetivo desconocido")
			end,

			["rareza inválida en un ítem se rechaza"] = function()
				local content = validContent()
				local item: any = content.items.a
				item.rarity = "Mítica"
				TestHarness.expect(expectRejected(content), "debería rechazar la rareza")
			end,

			["clave que no coincide con el id se rechaza"] = function()
				local content = validContent()
				content.items.a.id = "otro"
				TestHarness.expect(expectRejected(content), "debería rechazar el id desalineado")
			end,
		})
	end,
}

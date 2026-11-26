--!strict
--[[
	Validación de contenido al arrancar (solo datos, sin Instances, sin Roblox).
	Comprueba que cada referencia entre definiciones apunta a algo que existe y que cada clave
	coincide con el id de su entrada. Si algo falla, el servidor no arranca: mejor que fallar en partida.
]]
local Result = require(script.Parent.Parent.Util.Result)
local Types = require(script.Parent.Parent.Types)

export type Content = {
	items: { [string]: Types.ItemDef },
	abilities: { [string]: Types.AbilityDef },
	mobs: { [string]: Types.MobDef },
	dropTables: { [string]: Types.DropTable },
	zones: { [string]: Types.ZoneDef },
	quests: { [string]: Types.QuestDef },
}

-- Cada sección devuelve el primer error encontrado o nil si todo es válido.
type Section = (Content) -> string?

local VALID_RARITY: { [string]: boolean } = { Common = true, Rare = true, Epic = true, Legendary = true }
local VALID_KIND: { [string]: boolean } = { single = true, multi = true, area = true }

local function validateItems(content: Content): string?
	for key, item in content.items do
		if item.id ~= key then
			return `items.{key}: el id no coincide con la clave`
		end
		if #item.displayName == 0 then
			return `items.{key}: falta displayName`
		end
		if not VALID_RARITY[item.rarity] then
			return `items.{key}: rareza desconocida ({item.rarity})`
		end
		if item.maxStack < 1 or item.maxStack % 1 ~= 0 then
			return `items.{key}: maxStack debe ser un entero positivo`
		end
	end
	return nil
end

local function validateAbilities(content: Content): string?
	for key, ability in content.abilities do
		if ability.id ~= key then
			return `abilities.{key}: el id no coincide con la clave`
		end
		if ability.cooldown <= 0 or ability.range <= 0 then
			return `abilities.{key}: cooldown y range deben ser positivos`
		end
		if not VALID_KIND[ability.kind] then
			return `abilities.{key}: tipo desconocido ({ability.kind})`
		end
		if ability.kind == "area" and ability.radius <= 0 then
			return `abilities.{key}: un área necesita radius positivo`
		end
		if ability.kind == "multi" and ability.hits < 2 then
			return `abilities.{key}: un multi-golpe necesita al menos 2 golpes`
		end
		if ability.requiredLevel < 1 then
			return `abilities.{key}: requiredLevel debe ser al menos 1`
		end
		if not VALID_RARITY[ability.rarity] then
			return `abilities.{key}: rareza desconocida ({ability.rarity})`
		end
	end
	return nil
end

local function validateDropTables(content: Content): string?
	for tableId, dropTable in content.dropTables do
		for index, entry in dropTable.entries do
			if content.items[entry.itemId] == nil then
				return `dropTables.{tableId}[{index}]: ítem desconocido ({entry.itemId})`
			end
		end
	end
	return nil
end

local function validateMobs(content: Content): string?
	for key, mob in content.mobs do
		if mob.id ~= key then
			return `mobs.{key}: el id no coincide con la clave`
		end
		if content.dropTables[mob.dropTableId] == nil then
			return `mobs.{key}: tabla de drop desconocida ({mob.dropTableId})`
		end
		for _, ability in mob.abilities or {} do
			if ability ~= "charge" and ability ~= "shockwave" then
				return `mobs.{key}: habilidad desconocida ({ability})`
			end
		end
		if mob.abilities ~= nil and (mob.abilityCooldown or 0) <= 0 then
			return `mobs.{key}: con habilidades hace falta abilityCooldown positivo`
		end
	end
	return nil
end

local function validateZones(content: Content): string?
	for key, zone in content.zones do
		if zone.id ~= key then
			return `zones.{key}: el id no coincide con la clave`
		end
		for index, spawn in zone.spawns do
			if content.mobs[spawn.mobDefId] == nil then
				return `zones.{key}.spawns[{index}]: mob desconocido ({spawn.mobDefId})`
			end
			if spawn.respawnSeconds <= 0 then
				return `zones.{key}.spawns[{index}]: respawnSeconds debe ser positivo`
			end
		end
	end
	return nil
end

local function validateQuests(content: Content): string?
	for key, quest in content.quests do
		if quest.id ~= key then
			return `quests.{key}: el id no coincide con la clave`
		end
		if content.items[quest.reward.itemId] == nil then
			return `quests.{key}: recompensa con ítem desconocido ({quest.reward.itemId})`
		end
		local objective = quest.objective
		if objective.count < 1 then
			return `quests.{key}: count debe ser al menos 1`
		end
		if objective.kind == "killMob" then
			if content.mobs[objective.mobDefId] == nil then
				return `quests.{key}: objetivo con mob desconocido ({objective.mobDefId})`
			end
		elseif content.items[objective.itemId] == nil then
			return `quests.{key}: objetivo con ítem desconocido ({objective.itemId})`
		end
	end
	return nil
end

local SECTIONS: { Section } = {
	validateItems,
	validateAbilities,
	validateDropTables,
	validateMobs,
	validateZones,
	validateQuests,
}

local ContentValidator = {}

function ContentValidator.validate(content: Content): Result.Result<boolean>
	for _, validateSection in SECTIONS do
		local problem = validateSection(content)
		if problem ~= nil then
			return Result.err(problem)
		end
	end
	return Result.ok(true)
end

return table.freeze(ContentValidator)

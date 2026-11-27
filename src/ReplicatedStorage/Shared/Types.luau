--!strict
-- Contratos de datos compartidos entre cliente y servidor. Sin lógica.

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary"

export type AbilityDef = {
	id: string,
	displayName: string,
	cooldown: number, -- segundos
	range: number, -- studs
	damage: number,
	requiredLevel: number,
	rarity: Rarity,
	kind: "single" | "multi" | "area",
	radius: number, -- studs; solo para "area"
	hits: number, -- golpes; solo para "multi" (mínimo 2), 1 en el resto
}

export type DropEntry = {
	itemId: string,
	weight: number, -- entero positivo, relativo al total de la tabla
	minQuantity: number,
	maxQuantity: number,
}

export type DropTable = {
	entries: { DropEntry },
}

-- Categoría = pestaña del inventario y forma del emblema. Oro y gemas no son ítems: viven en la cartera.
export type ItemCategory = "pocion" | "llave" | "fruta" | "accesorio" | "material"

export type ItemDef = {
	id: string,
	displayName: string,
	rarity: Rarity,
	category: ItemCategory,
	maxStack: number, -- cantidad máxima por casilla de inventario
}

export type MobDef = {
	id: string,
	displayName: string,
	maxHealth: number,
	aggroRange: number,
	attackRange: number,
	leashRange: number,
	attackDamage: number,
	attackCooldown: number, -- segundos entre golpes
	dropTableId: string,
	xp: number, -- XP que da a cada jugador que contribuye
	templateId: string?, -- plantilla a clonar si no es la de su propio id (los jefes reutilizan un modelo)
	abilities: { string }?, -- habilidades especiales en orden, cíclico: "charge" (embestida) y "shockwave" (onda de choque)
	abilityCooldown: number?, -- segundos entre habilidades especiales
}

export type SpawnEntry = {
	mobDefId: string,
	spawnPointName: string, -- nombre de un BasePart dentro de workspace.Zones/<zona>/Spawns
	respawnSeconds: number,
}

export type ZoneDef = {
	id: string,
	displayName: string,
	spawns: { SpawnEntry },
}

export type QuestObjective =
	| { kind: "killMob", mobDefId: string, count: number }
	| { kind: "collectItem", itemId: string, count: number }

export type QuestDef = {
	id: string,
	title: string,
	objective: QuestObjective,
	reward: { itemId: string, quantity: number },
}

-- Cualquier cosa que el servidor pueda atacar. Implementada por los mobs.
export type CombatTarget = {
	getPosition: () -> Vector3,
	takeDamage: (amount: number, sourceUserId: number) -> (),
}

return {}

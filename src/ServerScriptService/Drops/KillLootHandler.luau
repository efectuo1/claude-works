--!strict
--[[
	Conecta la muerte de un mob con el loot. Es el único punto que conoce combate, drops e inventario a la vez.
	Así ninguno de los tres depende de los otros.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local DomainEvents = require(script.Parent.Parent.Events.DomainEvents)
local DropService = require(script.Parent.DropService)
local InventoryService = require(script.Parent.Parent.Inventory.InventoryService)
local Contribution = require(ReplicatedStorage.Shared.Util.Contribution)

export type Dependencies = {
	events: DomainEvents.Events,
	drops: DropService.DropService,
	inventory: InventoryService.InventoryService,
	mobDefs: { [string]: Types.MobDef },
	luckFor: ((userId: number) -> number)?, -- suerte del jugador (rango); opcional
	random: (() -> number)?, -- fuente de azar; por defecto math.random
}

local KillLootHandler = {}

function KillLootHandler.connect(deps: Dependencies)
	deps.events.mobKilled.connect(function(event)
		local mobDef = deps.mobDefs[event.mobDefId]
		if mobDef == nil then
			warn(`[Loot] mob sin definición: {event.mobDefId}`)
			return
		end

		-- Cada contribuyente tiene su parte de la probabilidad, según su daño.
		local random = deps.random or math.random
		local shares = Contribution.shares(event.damageByUserId, event.contributorUserIds)
		for userId, share in shares do
			if Contribution.attempt(share, random) then
				local luck = if deps.luckFor then deps.luckFor(userId) else 0
				local rolled = deps.drops.roll(mobDef.dropTableId, luck)
				if not rolled.ok then
					warn(`[Loot] tirada fallida para {mobDef.id}: {rolled.error}`)
				else
					local loot = rolled.value
					local stored = deps.inventory.add(userId, loot.itemId, loot.quantity)
					if not stored.ok then
						warn(`[Loot] inventario rechazó {loot.itemId}: {stored.error}`)
					else
						deps.events.itemCollected.fire({
							userId = userId,
							itemId = loot.itemId,
							quantity = loot.quantity,
						})
					end
				end
			end
		end
	end)
end

return KillLootHandler

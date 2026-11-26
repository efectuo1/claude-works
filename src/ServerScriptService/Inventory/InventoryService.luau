--!strict
--[[
	Inventario en memoria. Cada operación devuelve Result y no conoce combate ni misiones.
	Solo acepta ítems definidos en el catálogo y respeta el maxStack de cada uno.
	Se restaura desde el perfil al cargar y se exporta al guardar (ver Bootstrap).
	Pendiente para el comercio: registrar procedencia por ítem.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Shared.Util.Result)
local Types = require(ReplicatedStorage.Shared.Types)

export type InventoryService = {
	add: (userId: number, itemId: string, quantity: number) -> Result.Result<number>,
	count: (userId: number, itemId: string) -> number,
	export: (userId: number) -> { [string]: number },
	restore: (userId: number, stacks: { [string]: number }) -> Result.Result<boolean>,
	releasePlayer: (userId: number) -> (),
}

local InventoryService = {}

-- items: catálogo de ítems válidos (normalmente Definitions/Items). Sin catálogo no hay inventario.
function InventoryService.new(items: { [string]: Types.ItemDef }): InventoryService
	local stacks: { [number]: { [string]: number } } = {}

	local function isValidQuantity(quantity: number): boolean
		return quantity >= 1 and quantity % 1 == 0
	end

	local service = {}

	function service.add(userId: number, itemId: string, quantity: number): Result.Result<number>
		local itemDef = items[itemId]
		if itemDef == nil then
			return Result.err("item_unknown")
		end
		if not isValidQuantity(quantity) then
			return Result.err("quantity_invalid")
		end

		local userStacks = stacks[userId]
		if userStacks == nil then
			userStacks = {}
			stacks[userId] = userStacks
		end

		local nextTotal = (userStacks[itemId] or 0) + quantity
		if nextTotal > itemDef.maxStack then
			return Result.err("stack_full")
		end
		userStacks[itemId] = nextTotal
		return Result.ok(nextTotal)
	end

	function service.count(userId: number, itemId: string): number
		local userStacks = stacks[userId]
		if userStacks == nil then
			return 0
		end
		return userStacks[itemId] or 0
	end

	-- Copia: modificar el resultado no altera el inventario.
	function service.export(userId: number): { [string]: number }
		local copy: { [string]: number } = {}
		local userStacks = stacks[userId]
		if userStacks ~= nil then
			for itemId, count in userStacks do
				copy[itemId] = count
			end
		end
		return copy
	end

	-- Reemplaza el inventario del jugador. Valida todo antes de tocar el estado.
	function service.restore(userId: number, saved: { [string]: number }): Result.Result<boolean>
		local copy: { [string]: number } = {}
		for itemId, count in saved do
			if type(itemId) ~= "string" or items[itemId] == nil then
				return Result.err("item_unknown")
			end
			if type(count) ~= "number" or not isValidQuantity(count) or count > items[itemId].maxStack then
				return Result.err("quantity_invalid")
			end
			copy[itemId] = count
		end
		stacks[userId] = copy
		return Result.ok(true)
	end

	function service.releasePlayer(userId: number)
		stacks[userId] = nil
	end

	return service
end

return InventoryService

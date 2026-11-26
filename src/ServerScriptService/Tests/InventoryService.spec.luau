--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local InventoryService = require(ServerScriptService.Inventory.InventoryService)
local Items = require(ReplicatedStorage.Shared.Definitions.Items)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

local function newInventory()
	return InventoryService.new(Items)
end

return {
	run = function(): boolean
		return TestHarness.run("InventoryService", {
			["add acumula cantidades"] = function()
				local inv = newInventory()
				inv.add(1, "ember_shard", 2)
				inv.add(1, "ember_shard", 3)
				expect(inv.count(1, "ember_shard") == 5, "debería sumar 5")
			end,

			["add rechaza cantidades no válidas"] = function()
				local inv = newInventory()
				expect(not inv.add(1, "ember_shard", 0).ok, "cantidad 0 inválida")
				expect(not inv.add(1, "ember_shard", 1.5).ok, "cantidad fraccionaria inválida")
			end,

			["add rechaza ítems desconocidos"] = function()
				local inv = newInventory()
				local result = inv.add(1, "fantasma", 1)
				expect(not result.ok and result.error == "item_unknown", "debe rechazar ítems sin definición")
				expect(inv.count(1, "fantasma") == 0, "no debe guardar nada")
			end,

			["add respeta el maxStack de cada ítem"] = function()
				local inv = newInventory()
				-- stone_core tiene maxStack 99
				inv.add(1, "stone_core", 99)
				local overflow = inv.add(1, "stone_core", 1)
				expect(not overflow.ok and overflow.error == "stack_full", "debe rechazar pila llena")
			end,

			["export devuelve una copia independiente"] = function()
				local inv = newInventory()
				inv.add(1, "ember_shard", 4)
				local copy = inv.export(1)
				copy.ember_shard = 999
				expect(inv.count(1, "ember_shard") == 4, "modificar la copia no debe alterar el inventario")
			end,

			["restore reemplaza el inventario y valida antes de tocarlo"] = function()
				local inv = newInventory()
				inv.add(1, "ember_shard", 4)

				local rejected = inv.restore(1, { ember_shard = 0 })
				expect(not rejected.ok, "cantidad 0 debe rechazarse")
				expect(inv.count(1, "ember_shard") == 4, "un restore rechazado no debe tocar el estado")

				local unknown = inv.restore(1, { fantasma = 1 })
				expect(not unknown.ok, "ítem desconocido debe rechazarse")
				expect(inv.count(1, "ember_shard") == 4, "un restore con ítem desconocido no debe tocar el estado")

				local accepted = inv.restore(1, { stone_core = 2 })
				expect(accepted.ok, "restore válido debería aceptarse")
				expect(inv.count(1, "ember_shard") == 0, "restore reemplaza, no suma")
				expect(inv.count(1, "stone_core") == 2, "los ítems restaurados deben estar")
			end,
		})
	end,
}

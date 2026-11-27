--!strict
--[[
	Pociones: uso, compra y multiplicador de XP por jugador.
	- Usar una poción gasta una del inventario y la pone en el temporizador (ver Shared/Util/PotionTimer).
	- Comprar cuesta gemas (gemPrice de Definitions/Potions) y deja la poción en el inventario.
	- El estado del temporizador vive en memoria: no se guarda entre sesiones todavía.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Shared.Util.Result)
local PotionTimer = require(ReplicatedStorage.Shared.Util.PotionTimer)
local Potions = require(ReplicatedStorage.Shared.Definitions.Potions)

export type Dependencies = {
	items: { [string]: any }, -- catálogo de ítems: cada poción debe existir aquí
	inventory: {
		add: (userId: number, itemId: string, quantity: number) -> Result.Result<number>,
		remove: (userId: number, itemId: string, quantity: number) -> Result.Result<number>,
		count: (userId: number, itemId: string) -> number,
	},
	wallet: {
		spendGems: (userId: number, gems: number) -> Result.Result<boolean>,
		grantGems: (userId: number, gems: number, source: string) -> Result.Result<any>,
	},
	now: () -> number,
	onChanged: (userId: number) -> (), -- para que el servidor publique el estado como atributos
}

export type PotionService = {
	use: (userId: number, itemId: string) -> Result.Result<number>,
	buy: (userId: number, itemId: string) -> Result.Result<boolean>,
	multiplierFor: (userId: number) -> number,
	endsAtFor: (userId: number) -> number?,
	queuedFor: (userId: number) -> number,
	releasePlayer: (userId: number) -> (),
}

local PotionService = {}

function PotionService.new(deps: Dependencies): PotionService
	-- Sin ítem en el catálogo, la poción no se puede guardar: es un error de datos, no de partida.
	for potionId in Potions do
		assert(deps.items[potionId] ~= nil, `poción sin ítem en Definitions/Items: {potionId}`)
	end

	local states: { [number]: PotionTimer.State } = {}

	local function stateFor(userId: number): PotionTimer.State
		local state = states[userId]
		if state == nil then
			state = PotionTimer.new()
			states[userId] = state
		end
		return state
	end

	local service = {} :: PotionService

	-- Gasta una poción del inventario y la activa. Devuelve el momento en que termina.
	function service.use(userId: number, itemId: string): Result.Result<number>
		local potion = Potions[itemId]
		if potion == nil then
			return Result.err("no_es_pocion")
		end
		if deps.inventory.count(userId, itemId) < 1 then
			return Result.err("sin_pocion")
		end
		local removed = deps.inventory.remove(userId, itemId, 1)
		if not removed.ok then
			return Result.err(removed.error)
		end
		local now = deps.now()
		local state = stateFor(userId)
		PotionTimer.use(state, now, potion)
		deps.onChanged(userId)
		return Result.ok(PotionTimer.endsAt(state, now) or now)
	end

	-- Compra con gemas. Si el inventario no admite la poción, las gemas se devuelven.
	function service.buy(userId: number, itemId: string): Result.Result<boolean>
		local potion = Potions[itemId]
		if potion == nil then
			return Result.err("no_es_pocion")
		end
		local spent = deps.wallet.spendGems(userId, potion.gemPrice)
		if not spent.ok then
			return Result.err(spent.error)
		end
		local added = deps.inventory.add(userId, itemId, 1)
		if not added.ok then
			deps.wallet.grantGems(userId, potion.gemPrice, "reembolso")
			return Result.err(added.error)
		end
		return Result.ok(true)
	end

	function service.multiplierFor(userId: number): number
		local state = states[userId]
		if state == nil then
			return 1
		end
		return PotionTimer.multiplier(state, deps.now())
	end

	function service.endsAtFor(userId: number): number?
		local state = states[userId]
		if state == nil then
			return nil
		end
		return PotionTimer.endsAt(state, deps.now())
	end

	function service.queuedFor(userId: number): number
		local state = states[userId]
		if state == nil then
			return 0
		end
		PotionTimer.advance(state, deps.now())
		return PotionTimer.queued(state)
	end

	function service.releasePlayer(userId: number)
		states[userId] = nil
	end

	return service
end

return PotionService

--!strict
--[[
	Contratos de eventos de dominio y fábrica de señales.
	Se crea una instancia por servidor e se inyecta: nada de estado global.
]]

local Signal = require(script.Parent.Parent.Infrastructure.Signal)

export type MobKilledEvent = {
	instanceId: string,
	mobDefId: string,
	killerUserId: number,
	contributorUserIds: { number },
	damageByUserId: { [number]: number }?, -- daño real por jugador; si falta, se reparte a partes iguales
}

export type ItemCollectedEvent = {
	userId: number,
	itemId: string,
	quantity: number,
}

export type QuestCompletedEvent = {
	userId: number,
	questId: string,
}

export type Events = {
	mobKilled: Signal.Signal<MobKilledEvent>,
	itemCollected: Signal.Signal<ItemCollectedEvent>,
	questCompleted: Signal.Signal<QuestCompletedEvent>,
}

local DomainEvents = {}

function DomainEvents.create(): Events
	local mobKilled: Signal.Signal<MobKilledEvent> = Signal.new()
	local itemCollected: Signal.Signal<ItemCollectedEvent> = Signal.new()
	local questCompleted: Signal.Signal<QuestCompletedEvent> = Signal.new()
	return {
		mobKilled = mobKilled,
		itemCollected = itemCollected,
		questCompleted = questCompleted,
	}
end

return DomainEvents

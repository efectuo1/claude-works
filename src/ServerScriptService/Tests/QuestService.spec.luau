--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DomainEvents = require(ServerScriptService.Events.DomainEvents)
local QuestService = require(ServerScriptService.Quests.QuestService)
local Result = require(ReplicatedStorage.Shared.Util.Result)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

type Harness = {
	events: DomainEvents.Events,
	service: QuestService.QuestService,
	grants: { { itemId: string, quantity: number } },
}

local function makeHarness(): Harness
	local events = DomainEvents.create()
	local grants: { { itemId: string, quantity: number } } = {}
	local service = QuestService.new({
		events = events,
		grantReward = function(_userId, itemId, quantity)
			table.insert(grants, { itemId = itemId, quantity = quantity })
			return Result.ok(quantity)
		end,
	})
	return { events = events, service = service, grants = grants }
end

local function killWolf(h: Harness, userId: number)
	h.events.mobKilled.fire({
		instanceId = "wolf",
		mobDefId = "ember_wolf",
		killerUserId = userId,
		contributorUserIds = { userId },
	})
end

return {
	run = function(): boolean
		return TestHarness.run("QuestService", {
			["cuenta bajas y completa una sola vez con recompensa"] = function()
				local h = makeHarness()
				expect(h.service.start(1, "first_hunt").ok, "debería iniciar")
				for _ = 1, 5 do
					killWolf(h, 1)
				end
				expect(h.service.getActive(1) == nil, "la misión debería haberse completado")
				expect(#h.grants == 1, `debería recompensar una vez, recompensó {#h.grants}`)
				expect(h.grants[1].itemId == "ember_shard" and h.grants[1].quantity == 3, "recompensa incorrecta")
				killWolf(h, 1)
				expect(#h.grants == 1, "no debería recompensar dos veces")
			end,

			["no permite dos misiones activas a la vez"] = function()
				local h = makeHarness()
				h.service.start(1, "first_hunt")
				local second = h.service.start(1, "ember_collector")
				expect(not second.ok and second.error == "quest_already_active", "debería rechazarse")
			end,

			["los objetivos de recolección avanzan con itemCollected"] = function()
				local h = makeHarness()
				h.service.start(2, "ember_collector")
				h.events.itemCollected.fire({ userId = 2, itemId = "ember_shard", quantity = 10 })
				expect(#h.grants == 1 and h.grants[1].itemId == "stone_core", "debería completarse con 10 brasas")
			end,

			["una baja de otro mob no avanza la misión"] = function()
				local h = makeHarness()
				h.service.start(3, "first_hunt")
				h.events.mobKilled.fire({
					instanceId = "x",
					mobDefId = "ash_brute",
					killerUserId = 3,
					contributorUserIds = { 3 },
				})
				local active = h.service.getActive(3)
				expect(active ~= nil and active.count == 0, "el progreso no debería avanzar")
			end,

			["export y restore conservan la misión activa y las completadas"] = function()
				local h = makeHarness()
				h.service.start(3, "first_hunt")
				killWolf(h, 3)
				local saved = h.service.export(3)
				expect(saved.active ~= nil and saved.active.count == 1, "el progreso debe exportarse")

				local other = makeHarness()
				local restored = other.service.restore(3, saved)
				expect(restored.ok, "restore válido debería aceptarse")
				local active = other.service.getActive(3)
				expect(active ~= nil and active.count == 1, "el progreso debe restaurarse")
				expect(not other.service.start(3, "ember_collector").ok, "sigue habiendo una misión activa")
			end,

			["si la recompensa falla, la misión no se pierde y se reintenta"] = function()
				local events = DomainEvents.create()
				local grants: { number } = {}
				local failing = true
				local service = QuestService.new({
					events = events,
					grantReward = function(_userId, _itemId, quantity)
						if failing then
							return Result.err("inventario lleno")
						end
						table.insert(grants, quantity)
						return Result.ok(quantity)
					end,
				})
				local h: Harness = { events = events, service = service, grants = {} }
				expect(service.start(1, "first_hunt").ok, "debería iniciar")
				for _ = 1, 5 do
					killWolf(h, 1)
				end
				expect(service.getActive(1) ~= nil, "con recompensa fallida no debe completarse")
				expect(not service.export(1).completed.first_hunt, "no debe quedar marcada como completada")
				failing = false
				killWolf(h, 1)
				expect(#grants == 1, `debería reintentar y entregar una vez, entregó {#grants}`)
				expect(service.getActive(1) == nil, "tras entregar debería completarse")
			end,

			["restore acepta una recompensa pendiente (progreso igual al objetivo)"] = function()
				local h = makeHarness()
				expect(h.service.restore(9, { active = { questId = "first_hunt", count = 5 }, completed = {} }).ok, "progreso pendiente debe restaurarse")
			end,

			["restore rechaza misiones desconocidas o con progreso completo"] = function()
				local h = makeHarness()
				expect(not h.service.restore(4, { active = { questId = "nope", count = 0 }, completed = {} }).ok, "misión inexistente")
				expect(not h.service.restore(4, { active = { questId = "first_hunt", count = 6 }, completed = {} }).ok, "progreso por encima del objetivo no es válido")
				expect(not h.service.restore(4, { active = nil, completed = { nope = true } }).ok, "completada inexistente")
				expect(h.service.getActive(4) == nil, "un restore rechazado no debe tocar el estado")
			end,
		})
	end,
}

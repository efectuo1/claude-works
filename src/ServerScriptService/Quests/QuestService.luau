--!strict
--[[
	Misiones dirigidas por eventos. No conoce combate ni inventario: escucha señales
	y pide la recompensa mediante una dependencia inyectada.
	Vertical slice: una misión activa por jugador y progreso solo en memoria.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local QuestDefs = require(Shared.Definitions.Quests)
local Result = require(Shared.Util.Result)
local Types = require(Shared.Types)
local DomainEvents = require(script.Parent.Parent.Events.DomainEvents)

export type Dependencies = {
	events: DomainEvents.Events,
	grantReward: (userId: number, itemId: string, quantity: number) -> Result.Result<number>,
}

export type ActiveQuest = { questId: string, count: number }

export type QuestSnapshot = {
	active: ActiveQuest?,
	completed: { [string]: boolean },
}

export type QuestService = {
	start: (userId: number, questId: string) -> Result.Result<boolean>,
	getActive: (userId: number) -> ActiveQuest?,
	export: (userId: number) -> QuestSnapshot,
	restore: (userId: number, saved: QuestSnapshot) -> Result.Result<boolean>,
	releasePlayer: (userId: number) -> (),
}

local QuestService = {}

function QuestService.new(deps: Dependencies): QuestService
	local active: { [number]: ActiveQuest } = {}
	local completed: { [number]: { [string]: boolean } } = {}

	local function hasCompleted(userId: number, questId: string): boolean
		local set = completed[userId]
		return set ~= nil and set[questId] == true
	end

	local function markCompleted(userId: number, questId: string)
		local set = completed[userId]
		if set == nil then
			set = {}
			completed[userId] = set
		end
		set[questId] = true
	end

	-- Primero la recompensa; la misión solo se marca como completada si se entregó.
	-- Si falla, queda activa con el progreso al máximo y se reintenta en el siguiente evento compatible.
	local function complete(userId: number, quest: Types.QuestDef)
		local granted = deps.grantReward(userId, quest.reward.itemId, quest.reward.quantity)
		if not granted.ok then
			warn(`[Quests] recompensa pendiente para {userId} por {quest.id}: {granted.error}`)
			return
		end
		active[userId] = nil
		markCompleted(userId, quest.id)
		deps.events.questCompleted.fire({ userId = userId, questId = quest.id })
	end

	local function advance(userId: number, amount: number, matches: (Types.QuestObjective) -> boolean)
		local state = active[userId]
		if state == nil then
			return
		end
		local quest = QuestDefs[state.questId]
		if quest == nil or not matches(quest.objective) then
			return
		end

		state.count = math.min(state.count + amount, quest.objective.count)
		if state.count >= quest.objective.count then
			complete(userId, quest)
		end
	end

	deps.events.mobKilled.connect(function(event)
		for _, userId in event.contributorUserIds do
			advance(userId, 1, function(objective)
				return objective.kind == "killMob" and objective.mobDefId == event.mobDefId
			end)
		end
	end)

	deps.events.itemCollected.connect(function(event)
		advance(event.userId, event.quantity, function(objective)
			return objective.kind == "collectItem" and objective.itemId == event.itemId
		end)
	end)

	local service = {}

	function service.start(userId: number, questId: string): Result.Result<boolean>
		if QuestDefs[questId] == nil then
			return Result.err("quest_unknown")
		end
		if active[userId] ~= nil then
			return Result.err("quest_already_active")
		end
		if hasCompleted(userId, questId) then
			return Result.err("quest_already_completed")
		end
		active[userId] = { questId = questId, count = 0 }
		return Result.ok(true)
	end

	function service.getActive(userId: number): ActiveQuest?
		return active[userId]
	end

	-- Copia del progreso para guardarlo en el perfil.
	function service.export(userId: number): QuestSnapshot
		local current = active[userId]
		local done: { [string]: boolean } = {}
		for questId in completed[userId] or {} do
			done[questId] = true
		end
		return {
			active = if current then { questId = current.questId, count = current.count } else nil,
			completed = done,
		}
	end

	-- Restaura el progreso validando contra las definiciones de misiones. Todo o nada.
	function service.restore(userId: number, saved: QuestSnapshot): Result.Result<boolean>
		local done: { [string]: boolean } = {}
		for questId, flag in saved.completed do
			if QuestDefs[questId] == nil or flag ~= true then
				return Result.err("quest_unknown")
			end
			done[questId] = true
		end

		local current: ActiveQuest? = nil
		if saved.active ~= nil then
			local progress = saved.active
			local quest = QuestDefs[progress.questId]
			if quest == nil then
				return Result.err("quest_unknown")
			end
			if done[progress.questId] then
				return Result.err("quest_already_completed")
			end
			-- Progreso igual al objetivo = recompensa pendiente (se reintenta al siguiente evento).
			if progress.count < 0 or progress.count > quest.objective.count then
				return Result.err("quest_progress_invalid")
			end
			current = { questId = progress.questId, count = progress.count }
		end

		active[userId] = current
		completed[userId] = done
		return Result.ok(true)
	end

	function service.releasePlayer(userId: number)
		active[userId] = nil
		completed[userId] = nil
	end

	return service
end

return QuestService

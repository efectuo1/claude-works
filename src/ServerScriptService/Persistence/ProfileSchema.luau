--!strict
--[[
	Esquema versionado del perfil del jugador: valores por defecto, migraciones y validación.
	Lógica pura (sin Instances), así que se prueba sin Studio.
	Regla: un perfil que no se puede validar NO se sobrescribe. Mejor fallar la carga que perder datos.

	Historial:
	- v1: nivel e inventario.
	- v2: progreso de misiones (misión activa y completadas).
	- v3: experiencia (xp). Los perfiles antiguos reciben el XP mínimo de su nivel.
	- v4: oro, gemas y rango. Los perfiles antiguos empiezan con 0 y rango novato.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Shared.Util.Result)
local Progression = require(ReplicatedStorage.Shared.Util.Progression)

export type QuestProgress = { questId: string, count: number }

export type ProfileQuests = {
	active: QuestProgress?,
	completed: { [string]: boolean },
}

export type ProfileData = {
	schemaVersion: number,
	contentVersion: number,
	level: number,
	xp: number,
	inventory: { [string]: number },
	quests: ProfileQuests,
	gold: number,
	gems: number,
	rank: string,
}

local CURRENT_VERSION = 4
local CONTENT_VERSION = 1

-- MIGRATIONS[v] convierte datos de la versión v a v + 1. Nunca se editan migraciones ya publicadas.
local MIGRATIONS: { [number]: (raw: { [string]: unknown }) -> { [string]: unknown } } = {
	[1] = function(raw)
		local out: { [string]: unknown } = {}
		for key, value in raw do
			out[key] = value
		end
		out.schemaVersion = 2
		out.quests = { completed = {} }
		return out
	end,
	[2] = function(raw)
		local out: { [string]: unknown } = {}
		for key, value in raw do
			out[key] = value
		end
		out.schemaVersion = 3
		local level = raw.level
		-- XP mínimo de su nivel: así nadie retrocede de nivel al migrar.
		out.xp = if type(level) == "number" and level % 1 == 0 and level >= 1 then Progression.xpForLevel(level) else 0
		return out
	end,
	[3] = function(raw)
		local out: { [string]: unknown } = {}
		for key, value in raw do
			out[key] = value
		end
		out.schemaVersion = 4
		out.gold = 0
		out.gems = 0
		out.rank = "novato"
		return out
	end,
}

local ProfileSchema = {}

ProfileSchema.CURRENT_VERSION = CURRENT_VERSION
ProfileSchema.CONTENT_VERSION = CONTENT_VERSION

function ProfileSchema.defaults(): ProfileData
	return {
		schemaVersion = CURRENT_VERSION,
		contentVersion = CONTENT_VERSION,
		level = 1,
		xp = 0,
		inventory = {},
		quests = { active = nil, completed = {} },
		gold = 0,
		gems = 0,
		rank = "novato",
	}
end

-- Valida la forma de datos ya en versión actual y devuelve una copia limpia.
function ProfileSchema.validate(raw: unknown): Result.Result<ProfileData>
	if type(raw) ~= "table" then
		return Result.err("profile_corrupt")
	end
	local data = raw :: { [string]: unknown }

	local level = data.level
	if type(level) ~= "number" or level % 1 ~= 0 or level < 1 then
		return Result.err("profile_corrupt")
	end

	local xp = data.xp
	if type(xp) ~= "number" or xp % 1 ~= 0 or xp < 0 then
		return Result.err("profile_corrupt")
	end

	local contentVersion = data.contentVersion
	if type(contentVersion) ~= "number" or contentVersion % 1 ~= 0 or contentVersion < 1 then
		return Result.err("profile_corrupt")
	end

	local gold = data.gold
	if type(gold) ~= "number" or gold % 1 ~= 0 or gold < 0 then
		return Result.err("profile_corrupt")
	end

	local gems = data.gems
	if type(gems) ~= "number" or gems % 1 ~= 0 or gems < 0 then
		return Result.err("profile_corrupt")
	end

	local rank = data.rank
	if type(rank) ~= "string" or #rank == 0 then
		return Result.err("profile_corrupt")
	end

	local rawInventory = data.inventory
	if type(rawInventory) ~= "table" then
		return Result.err("profile_corrupt")
	end
	local inventory: { [string]: number } = {}
	for itemId, count in (rawInventory :: { [unknown]: unknown }) do
		if type(itemId) ~= "string" or #itemId == 0 then
			return Result.err("profile_corrupt")
		end
		if type(count) ~= "number" or count % 1 ~= 0 or count < 1 then
			return Result.err("profile_corrupt")
		end
		inventory[itemId] = count
	end

	local rawQuests = data.quests
	if type(rawQuests) ~= "table" then
		return Result.err("profile_corrupt")
	end
	local quests = rawQuests :: { [string]: unknown }

	local rawCompleted = quests.completed
	if type(rawCompleted) ~= "table" then
		return Result.err("profile_corrupt")
	end
	local completed: { [string]: boolean } = {}
	for questId, flag in (rawCompleted :: { [unknown]: unknown }) do
		if type(questId) ~= "string" or #questId == 0 or flag ~= true then
			return Result.err("profile_corrupt")
		end
		completed[questId] = true
	end

	local active: QuestProgress? = nil
	local rawActive = quests.active
	if rawActive ~= nil then
		if type(rawActive) ~= "table" then
			return Result.err("profile_corrupt")
		end
		local progress = rawActive :: { [string]: unknown }
		local questId = progress.questId
		local count = progress.count
		if type(questId) ~= "string" or #questId == 0 then
			return Result.err("profile_corrupt")
		end
		if type(count) ~= "number" or count % 1 ~= 0 or count < 0 then
			return Result.err("profile_corrupt")
		end
		active = { questId = questId, count = count }
	end

	return Result.ok({
		schemaVersion = CURRENT_VERSION,
		contentVersion = contentVersion,
		level = level,
		xp = xp,
		inventory = inventory,
		quests = { active = active, completed = completed },
		gold = gold,
		gems = gems,
		rank = rank,
	})
end

-- Lleva datos guardados (cualquier versión conocida) a la versión actual y los valida.
function ProfileSchema.migrate(raw: unknown): Result.Result<ProfileData>
	if type(raw) ~= "table" then
		return Result.err("profile_corrupt")
	end
	local data = raw :: { [string]: unknown }

	local version = data.schemaVersion
	if type(version) ~= "number" or version % 1 ~= 0 or version < 1 then
		return Result.err("profile_corrupt")
	end
	if version > CURRENT_VERSION then
		-- Datos de una versión posterior del servidor: no se tocan.
		return Result.err("profile_from_newer_version")
	end

	for v = version, CURRENT_VERSION - 1 do
		local migrate = MIGRATIONS[v]
		if migrate == nil then
			return Result.err("profile_migration_missing")
		end
		data = migrate(data)
	end

	return ProfileSchema.validate(data)
end

return table.freeze(ProfileSchema)

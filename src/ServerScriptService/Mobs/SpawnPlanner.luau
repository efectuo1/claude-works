--!strict
--[[
	Planificación pura de spawns: valida una zona y genera un slot por punto de aparición.
	No toca Instances, así que se prueba sin Studio.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local MobDefs = require(Shared.Definitions.Mobs)
local Result = require(Shared.Util.Result)
local Types = require(Shared.Types)

export type SpawnSlot = {
	instanceId: string,
	mobDefId: string,
	spawnPointName: string,
	respawnSeconds: number,
}

local MIN_RESPAWN_SECONDS = 1

local SpawnPlanner = {}

function SpawnPlanner.plan(zone: Types.ZoneDef): Result.Result<{ SpawnSlot }>
	local seenPoints: { [string]: boolean } = {}
	local slots: { SpawnSlot } = {}

	for _, entry in zone.spawns do
		if MobDefs[entry.mobDefId] == nil then
			return Result.err(`{zone.id}: mob desconocido {entry.mobDefId}`)
		end
		if seenPoints[entry.spawnPointName] then
			return Result.err(`{zone.id}: punto de spawn duplicado {entry.spawnPointName}`)
		end
		if entry.respawnSeconds < MIN_RESPAWN_SECONDS then
			return Result.err(`{zone.id}: respawn demasiado corto en {entry.spawnPointName}`)
		end

		seenPoints[entry.spawnPointName] = true
		table.insert(slots, {
			instanceId = `{zone.id}/{entry.spawnPointName}`,
			mobDefId = entry.mobDefId,
			spawnPointName = entry.spawnPointName,
			respawnSeconds = entry.respawnSeconds,
		})
	end

	return Result.ok(slots)
end

return SpawnPlanner

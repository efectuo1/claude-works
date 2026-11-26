--!strict
--[[
	Concede XP y sube de nivel. Escribe en el perfil en memoria; ProfileService lo guarda.
	Un nivel nuevo se comunica a través de onLevelChanged (para que el cliente lo vea).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Progression = require(ReplicatedStorage.Shared.Util.Progression)
local Result = require(ReplicatedStorage.Shared.Util.Result)
local ProfileSchema = require(script.Parent.Parent.Persistence.ProfileSchema)

export type Dependencies = {
	getProfile: (userId: number) -> ProfileSchema.ProfileData?,
	onLevelChanged: (userId: number, level: number) -> (),
	onXpChanged: ((userId: number, xp: number) -> ())?, -- opcional: la interfaz lo muestra
}

export type ProgressionService = {
	grant: (userId: number, amount: number) -> Result.Result<number>,
}

local ProgressionService = {}

function ProgressionService.new(deps: Dependencies): ProgressionService
	local service = {}

	-- Devuelve el nivel resultante. Solo XP entero y positivo.
	function service.grant(userId: number, amount: number): Result.Result<number>
		if amount <= 0 or amount % 1 ~= 0 then
			return Result.err("xp_invalid")
		end
		local data = deps.getProfile(userId)
		if data == nil then
			return Result.err("profile_not_loaded")
		end
		local before = data.level
		data.xp += amount
		data.level = Progression.levelForXp(data.xp)
		if deps.onXpChanged then
			deps.onXpChanged(userId, data.xp)
		end
		if data.level ~= before then
			deps.onLevelChanged(userId, data.level)
		end
		return Result.ok(data.level)
	end

	return service
end

return ProgressionService

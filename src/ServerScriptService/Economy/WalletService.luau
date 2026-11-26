--!strict
--[[
	Monedero del jugador: oro, gemas y rango. Escribe en el perfil cargado (igual que
	ProgressionService) y el autoguardado lo persiste. Las cantidades salen de Rewards.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Shared.Util.Result)
local Rewards = require(ReplicatedStorage.Shared.Util.Rewards)
local ProfileSchema = require(script.Parent.Parent.Persistence.ProfileSchema)
local Perks = require(ReplicatedStorage.Shared.Util.Perks)

export type Dependencies = {
	getProfile: (userId: number) -> ProfileSchema.ProfileData?,
	rng: Random,
	onChanged: (userId: number, data: ProfileSchema.ProfileData) -> (),
	onGranted: (userId: number, grant: Rewards.Grant, source: string) -> (),
	perksFor: (userId: number) -> Perks.Perks,
}

local WalletService = {}

function WalletService.new(deps: Dependencies)
	local service = {}

	local function apply(userId: number, grant: Rewards.Grant, source: string): Result.Result<Rewards.Grant>
		local data = deps.getProfile(userId)
		if data == nil then
			return Result.err("profile_not_loaded")
		end
		data.gold += grant.gold
		data.gems += grant.gems
		deps.onChanged(userId, data)
		if grant.gold > 0 or grant.gems > 0 then
			deps.onGranted(userId, grant, source)
		end
		return Result.ok(grant)
	end

	-- Mob: el oro llega ya tirado (pool) y se reparte según la participación. Las gemas se tiran por persona.
	function service.rewardMob(userId: number, mobId: string, share: number?, pool: number?): Result.Result<Rewards.Grant>
		local data = deps.getProfile(userId)
		if data == nil then
			return Result.err("profile_not_loaded")
		end
		local grant = Rewards.rollMob(mobId, Rewards.rankOrDefault(data.rank), deps.rng, share, pool, deps.perksFor(userId))
		return apply(userId, grant, "mob")
	end

	function service.rewardQuest(userId: number, questId: string): Result.Result<Rewards.Grant>
		local data = deps.getProfile(userId)
		if data == nil then
			return Result.err("profile_not_loaded")
		end
		local grant = Rewards.questGrant(questId, Rewards.rankOrDefault(data.rank))
		return apply(userId, grant, "quest")
	end

	-- Valida primero y descuenta después: sin hilos, así que la operación es atómica.
	function service.rankUp(userId: number): Result.Result<string>
		local data = deps.getProfile(userId)
		if data == nil then
			return Result.err("profile_not_loaded")
		end
		local check = Rewards.canRankUp(data.level, data.gold, data.gems, data.rank)
		if not check.ok then
			return Result.err(check.error)
		end
		local target = check.value
		data.gold -= target.cost.gold
		data.gems -= target.cost.gems
		data.rank = target.id
		deps.onChanged(userId, data)
		return Result.ok(target.id)
	end

	-- Regalo directo (p. ej. gemas segura de una oleada). Pasa por el mismo camino que cualquier recompensa.
	function service.grantGems(userId: number, gems: number, source: string): Result.Result<Rewards.Grant>
		return apply(userId, { gold = 0, gems = gems }, source)
	end

	-- Cambio oro <-> gemas. Valida y aplica de una vez (sin hilos, así que es atómico).
	function service.exchange(userId: number, direction: string, amount: number): Result.Result<Rewards.Balance>
		local data = deps.getProfile(userId)
		if data == nil then
			return Result.err("profile_not_loaded")
		end
		local changed = Rewards.exchange(direction, amount, { gold = data.gold, gems = data.gems })
		if not changed.ok then
			return Result.err(changed.error)
		end
		data.gold = changed.value.gold
		data.gems = changed.value.gems
		deps.onChanged(userId, data)
		return Result.ok(changed.value)
	end

	return service
end

return WalletService

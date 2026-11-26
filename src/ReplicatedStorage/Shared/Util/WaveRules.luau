--!strict
--[[
	Modalidad de oleadas (arena): reglas puras, sin Roblox.
	20 oleadas. Las oleadas 5, 10 y 15 tienen mini jefe y gema segura. La 20 tiene jefe final.
	Qué mobs salen lo decide RoundPlanner; aquí solo se decide qué significa cada oleada.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Shared.Util.Result)
local RoundPlanner = require(ReplicatedStorage.Shared.Util.RoundPlanner)

local WaveRules = {}

WaveRules.MAX_WAVES = 20
WaveRules.BOSS_EVERY = 5
WaveRules.MINI_BOSS = "ash_captain"
WaveRules.FINAL_BOSS = "ember_tyrant"

export type WaveInfo = {
	wave: number,
	mobs: { string },
	miniBoss: boolean,
	finalBoss: boolean,
	safeGem: boolean,
}

function WaveRules.info(wave: number): Result.Result<WaveInfo>
	if wave % 1 ~= 0 or wave < 1 or wave > WaveRules.MAX_WAVES then
		return Result.err("oleada_invalida")
	end
	local planned = RoundPlanner.plan(wave)
	if not planned.ok then
		return Result.err(planned.error)
	end
	local finalBoss = wave == WaveRules.MAX_WAVES
	local miniBoss = wave % WaveRules.BOSS_EVERY == 0 and not finalBoss
	-- El mob fuerte de la ronda pasa a ser el jefe de la oleada.
	local strong = RoundPlanner.strongMob()
	local mobs = table.clone(planned.value)
	for index, mobDefId in mobs do
		if mobDefId == strong then
			if finalBoss then
				mobs[index] = WaveRules.FINAL_BOSS
			elseif miniBoss then
				mobs[index] = WaveRules.MINI_BOSS
			end
		end
	end
	return Result.ok({
		wave = wave,
		mobs = mobs,
		miniBoss = miniBoss,
		finalBoss = finalBoss,
		safeGem = miniBoss,
	})
end

return table.freeze(WaveRules)

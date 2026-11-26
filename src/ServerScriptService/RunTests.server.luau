--!strict
--[[
	Ejecuta todas las suites al arrancar en Studio. En un servidor publicado no hace nada.
	Los nombres de módulo llevan punto (p. ej. "AbilityService.spec"), así que se resuelven con WaitForChild.
]]
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

if not RunService:IsStudio() then
	return
end

local suiteNames = {
	"AbilityService.spec",
	"DropService.spec",
	"MobStateMachine.spec",
	"Mob.spec",
	"Signal.spec",
	"QuestService.spec",
	"SpawnPlanner.spec",
	"InventoryService.spec",
	"ContentValidator.spec",
	"ProfileService.spec",
	"MobScheduler.spec",
	"AnimationCritic.spec",
	"PlayerPresence.spec",
	"Progression.spec",
	"Roulette.spec",
	"RoundPlanner.spec",
	"MapLayout.spec",
	"Rewards.spec",
	"GamePassService.spec",
	"WaveSession.spec",
	"DropLuck.spec",
	"Contribution.spec",
	"InstanceRouter.spec",
	"PotionTimer.spec",
}

local tests = ServerScriptService:WaitForChild("Tests")
local allPassed = true

for _, name in suiteNames do
	local suite = require(tests:WaitForChild(name))
	if not suite.run() then
		allPassed = false
	end
end

print(if allPassed then "[Tests] todas las suites pasaron" else "[Tests] hay suites con fallos")

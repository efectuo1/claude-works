--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local MobStateMachine = require(ServerScriptService.Mobs.MobStateMachine)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

local function perception(overrides: { [string]: number? }): MobStateMachine.Perception
	local base = {
		health = 100,
		distanceFromHome = 0,
		distanceToTarget = nil :: number?,
		aggroRange = 20,
		attackRange = 5,
		leashRange = 40,
	}
	for key, value in overrides do
		(base :: any)[key] = value
	end
	return base :: MobStateMachine.Perception
end

return {
	run = function(): boolean
		return TestHarness.run("MobStateMachine", {
			["patrulla sin objetivo"] = function()
				expect(MobStateMachine.nextState("Patrol", perception({})) == "Patrol", "debería patrullar")
			end,

			["detecta y persigue dentro del aggro"] = function()
				local state = MobStateMachine.nextState("Patrol", perception({ distanceToTarget = 15 }))
				expect(state == "Chase", "debería perseguir")
			end,

			["ataca dentro del rango de ataque"] = function()
				local state = MobStateMachine.nextState("Chase", perception({ distanceToTarget = 3 }))
				expect(state == "Attack", "debería atacar")
			end,

			["vuelve a casa si pierde al objetivo"] = function()
				local state = MobStateMachine.nextState("Chase", perception({ distanceToTarget = 25 }))
				expect(state == "Return", "debería volver")
			end,

			["vuelve a casa al salir de la correa"] = function()
				local state = MobStateMachine.nextState("Chase", perception({ distanceToTarget = 2, distanceFromHome = 50 }))
				expect(state == "Return", "la correa debe tener prioridad")
			end,

			["no vuelve a detectar mientras regresa"] = function()
				local state = MobStateMachine.nextState("Return", perception({ distanceToTarget = 2, distanceFromHome = 10 }))
				expect(state == "Return", "no debería reenganchar durante el regreso")
			end,

			["termina el regreso al llegar a casa"] = function()
				local state = MobStateMachine.nextState("Return", perception({ distanceFromHome = 0.5 }))
				expect(state == "Patrol", "debería volver a patrullar")
			end,

			["muere con vida cero desde cualquier estado"] = function()
				local state = MobStateMachine.nextState("Attack", perception({ health = 0, distanceToTarget = 1 }))
				expect(state == "Dead", "debería estar muerto")
			end,
		})
	end,
}

--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerPresence = require(ServerScriptService.Players.PlayerPresence)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

return {
	run = function(): boolean
		return TestHarness.run("PlayerPresence", {
			["un jugador conectado está presente"] = function()
				local presence = PlayerPresence.new(function(userId: number)
					return if userId == 1 then ({} :: any) :: Player else nil
				end)
				expect(presence.isPresent(1), "el jugador 1 debería estar presente")
				expect(not presence.isPresent(2), "el jugador 2 no está conectado")
			end,

			["un jugador que se va deja de estar presente aunque siga listado"] = function()
				local presence = PlayerPresence.new(function(_: number)
					return ({} :: any) :: Player
				end)
				expect(presence.isPresent(7), "debería estar presente antes de salir")
				presence.markLeaving(7)
				expect(not presence.isPresent(7), "no debería estar presente al salir")
				expect(presence.isLeaving(7), "debería marcarse como saliendo")
				expect(not presence.isLeaving(8), "otro jugador no sale")
			end,
		})
	end,
}

--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Signal = require(ServerScriptService.Infrastructure.Signal)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

return {
	run = function(): boolean
		return TestHarness.run("Signal", {
			["un listener que falla no detiene a los demás"] = function()
				local signal: Signal.Signal<number> = Signal.new()
				local reached = false
				signal.connect(function()
					error("fallo intencional")
				end)
				signal.connect(function()
					reached = true
				end)
				signal.fire(1)
				expect(reached, "el segundo listener debería ejecutarse")
			end,

			["disconnect deja de notificar"] = function()
				local signal: Signal.Signal<number> = Signal.new()
				local calls = 0
				local connection = signal.connect(function()
					calls += 1
				end)
				signal.fire(1)
				connection.disconnect()
				signal.fire(2)
				expect(calls == 1, `debería llamarse una vez, se llamó {calls}`)
			end,
		})
	end,
}

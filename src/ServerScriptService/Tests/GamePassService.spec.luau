--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local GamePassService = require(ServerScriptService.Monetization.GamePassService)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

local CATALOG = {
	{ id = "oro_x2", title = "Oro x2", desc = "", price = 1, gamePassId = 5, perk = { goldMult = 2 } },
	{ id = "sin_id", title = "Sin ID", desc = "", price = 1, gamePassId = 0, perk = { luck = 0.1 } },
}

return {
	run = function(): boolean
		return TestHarness.run("GamePassService", {
			["un pase comprado en Roblox da su efecto"] = function()
				local service = GamePassService.new(function(_userId: number, gamePassId: number): boolean
					return gamePassId == 5
				end, CATALOG)
				service.refresh(1)
				expect(service.owns(1, "oro_x2"), "debe figurar como comprado")
				expect(service.perksFor(1).goldMult == 2, "debe dar oro x2")
			end,

			["sin pase comprado los efectos son neutros"] = function()
				local service = GamePassService.new(function(): boolean
					return false
				end, CATALOG)
				service.refresh(1)
				expect(not service.owns(1, "oro_x2"), "no debe figurar como comprado")
				expect(service.perksFor(1).goldMult == 1, "sin pase el oro es x1")
			end,

			["un pase sin ID no se pregunta ni cuenta como comprado"] = function()
				local asked = false
				local service = GamePassService.new(function(_userId: number, gamePassId: number): boolean
					if gamePassId == 0 then
						asked = true
					end
					return true
				end, CATALOG)
				service.refresh(1)
				expect(not asked, "no debe preguntar por el ID 0")
				expect(not service.owns(1, "sin_id"), "un pase sin ID no es comprable")
			end,

			["al olvidar a un jugador se borran sus pases"] = function()
				local service = GamePassService.new(function(): boolean
					return true
				end, CATALOG)
				service.refresh(1)
				service.forget(1)
				expect(not service.owns(1, "oro_x2"), "tras olvidar no debe quedar nada")
			end,

			["si la consulta a Roblox falla, cuenta como no comprado"] = function()
				local fake = { UserOwnsGamePassAsync = function(): boolean
					error("sin servicios de API")
				end }
				local check = GamePassService.robuxCheck(fake :: any)
				expect(check(1, 5) == false, "un error debe contar como no comprado")
			end,

			["la consulta a Roblox devuelve la propiedad real"] = function()
				local fake = { UserOwnsGamePassAsync = function(_self: any, userId: number, gamePassId: number): boolean
					return userId == 1 and gamePassId == 5
				end }
				local check = GamePassService.robuxCheck(fake :: any)
				expect(check(1, 5) == true, "debe devolver true si Roblox lo confirma")
			end,
		})
	end,
}

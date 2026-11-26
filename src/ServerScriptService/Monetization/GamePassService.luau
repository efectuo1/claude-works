--!strict
--[[
	Dueños de pases de Robux. Pregunta a Roblox al entrar y tras cada compra, guarda el resultado
	en memoria y lo expone como efectos (Perks). Si la pregunta falla, cuenta como "no lo tiene".
	La pregunta a Roblox va inyectada: así la lógica se prueba sin Studio.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Perks = require(ReplicatedStorage.Shared.Util.Perks)
local Shop = require(ReplicatedStorage.Shared.Definitions.Shop)

export type Ownership = {
	refresh: (userId: number) -> (),
	owns: (userId: number, passId: string) -> boolean,
	perksFor: (userId: number) -> Perks.Perks,
	forget: (userId: number) -> (),
}

local GamePassService = {}

-- ownsOnRobux(userId, gamePassId) -> boolean. Un pase con gamePassId 0 todavía no existe: no se pregunta.
-- catalog: por defecto, el de Shop. Se inyecta en las pruebas.
function GamePassService.new(ownsOnRobux: (number, number) -> boolean, catalog: { Shop.GamePass }?): Ownership
	local passes = catalog or Shop.GAMEPASSES
	local owned: { [number]: { [string]: boolean } } = {}
	local service = {}

	function service.refresh(userId: number)
		local list: { [string]: boolean } = {}
		for _, pass in passes do
			list[pass.id] = pass.gamePassId ~= 0 and ownsOnRobux(userId, pass.gamePassId)
		end
		owned[userId] = list
	end

	function service.owns(userId: number, passId: string): boolean
		local list = owned[userId]
		return list ~= nil and list[passId] == true
	end

	function service.perksFor(userId: number): Perks.Perks
		return Perks.fromPasses(passes, function(id: string): boolean
			return service.owns(userId, id)
		end)
	end

	function service.forget(userId: number)
		owned[userId] = nil
	end

	return service
end

-- Consulta real a Roblox. Si falla (por ejemplo sin servicios de API en Studio), cuenta como no comprado.
function GamePassService.robuxCheck(marketplace: MarketplaceService): (number, number) -> boolean
	return function(userId: number, gamePassId: number): boolean
		local ok, result = pcall(function()
			return marketplace:UserOwnsGamePassAsync(userId, gamePassId)
		end)
		return ok and result == true
	end
end

return GamePassService

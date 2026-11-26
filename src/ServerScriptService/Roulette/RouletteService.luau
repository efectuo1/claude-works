--!strict
--[[
	Servicio de la ruleta (autoritativo en servidor). Elige premio, lo entrega y aplica enfriamiento.
	El premio solo cuenta si la entrega tiene éxito: si falla, no se gasta el enfriamiento.
	No conoce Players ni Remotes: todo llega por dependencias inyectadas.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Roulette = require(Shared.Definitions.Roulette)
local TestConfig = require(Shared.Definitions.TestConfig)
local Result = require(Shared.Util.Result)

export type Dependencies = {
	now: () -> number,
	allowRequest: (userId: number) -> boolean,
	random: () -> number, -- devuelve un número en [0, 1)
	deliver: (userId: number, prize: Roulette.Prize) -> Result.Result<boolean>,
	cooldownSeconds: number,
}

export type RouletteService = {
	spin: (userId: number) -> Result.Result<Roulette.Prize>,
	releasePlayer: (userId: number) -> (),
}

local RouletteService = {}

function RouletteService.new(deps: Dependencies): RouletteService
	local readyAtByUser: { [number]: number } = {}

	local service = {}

	function service.spin(userId: number): Result.Result<Roulette.Prize>
		if not deps.allowRequest(userId) then
			return Result.err("rate_limited")
		end
		local now = deps.now()
		if not TestConfig.NO_COOLDOWNS and now < (readyAtByUser[userId] or 0) then
			return Result.err("cooldown")
		end

		local prize = Roulette.pick(Roulette.prizes(), deps.random())
		if prize == nil then
			return Result.err("sin_premios")
		end

		local delivered = deps.deliver(userId, prize)
		if not delivered.ok then
			-- Sin entrega no hay premio: el jugador puede volver a intentarlo sin esperar.
			return Result.err(delivered.error)
		end

		readyAtByUser[userId] = now + deps.cooldownSeconds
		return Result.ok(prize)
	end

	function service.releasePlayer(userId: number)
		readyAtByUser[userId] = nil
	end

	return service
end

return RouletteService

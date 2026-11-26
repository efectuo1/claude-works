--!strict
--[[
	Estado de una partida de oleadas. Pura: cada paso devuelve un estado nuevo y, si pasa algo
	importante, un evento ("oleada_superada", "victoria", "derrota"). El servidor aplica los eventos.
	Un estado terminado ya no cambia.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Shared.Util.Result)
local WaveRules = require(ReplicatedStorage.Shared.Util.WaveRules)

local WaveSession = {}

export type Status = "activa" | "victoria" | "derrota"
export type Session = { wave: number, remaining: number, status: Status }
export type Event = "oleada_superada" | "victoria" | "derrota"

-- Empieza en la oleada 1 con todos sus mobs por matar.
function WaveSession.start(): Result.Result<Session>
	local first = WaveRules.info(1)
	if not first.ok then
		return Result.err(first.error)
	end
	return Result.ok({ wave = 1, remaining = #first.value.mobs, status = "activa" })
end

-- n mobs de la oleada han muerto. Al llegar a cero se avanza; tras la última oleada es victoria.
function WaveSession.mobsKilled(session: Session, n: number): (Session, Event?)
	if session.status ~= "activa" or n < 1 then
		return session, nil
	end
	local remaining = math.max(0, session.remaining - n)
	if remaining > 0 then
		return { wave = session.wave, remaining = remaining, status = "activa" }, nil
	end
	if session.wave >= WaveRules.MAX_WAVES then
		return { wave = session.wave, remaining = 0, status = "victoria" }, "victoria"
	end
	local nextWave = session.wave + 1
	local nextInfo = WaveRules.info(nextWave)
	if not nextInfo.ok then
		return session, nil
	end
	return { wave = nextWave, remaining = #nextInfo.value.mobs, status = "activa" }, "oleada_superada"
end

-- Si ya no queda nadie en la arena, la partida se pierde.
function WaveSession.playersLeft(session: Session, count: number): (Session, Event?)
	if session.status ~= "activa" or count > 0 then
		return session, nil
	end
	return { wave = session.wave, remaining = session.remaining, status = "derrota" }, "derrota"
end

return table.freeze(WaveSession)

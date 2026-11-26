--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local WaveRules = require(ReplicatedStorage.Shared.Util.WaveRules)
local WaveSession = require(ReplicatedStorage.Shared.Util.WaveSession)
local Result = require(ReplicatedStorage.Shared.Util.Result)
local MobDefs = require(ReplicatedStorage.Shared.Definitions.Mobs)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

-- Arranca una partida o falla la prueba con el motivo.
local function started(): WaveSession.Session
	local result = WaveSession.start()
	expect(result.ok, "la partida debe empezar")
	return (result :: any).value
end

return {
	run = function(): boolean
		return TestHarness.run("WaveSession", {
			["la partida empieza en la oleada 1 con sus mobs"] = function()
				local session = started()
				expect(session.wave == 1 and session.status == "activa", "debe empezar en la 1 y activa")
				expect(session.remaining == #WaveRules.info(1).value.mobs, "remaining debe ser los mobs de la 1")
			end,

			["matar sin acabar la oleada no la avanza"] = function()
				local session, event = WaveSession.mobsKilled(started(), 1)
				expect(event == nil and session.wave == 1, "no debe avanzar con mobs vivos")
			end,

			["acabar una oleada avanza a la siguiente"] = function()
				local session = started()
				local nextSession, event = WaveSession.mobsKilled(session, session.remaining)
				expect(event == "oleada_superada" and nextSession.wave == 2, "debe pasar a la oleada 2")
				expect(nextSession.remaining == #WaveRules.info(2).value.mobs, "la 2 trae sus mobs")
			end,

			["acabar la última oleada da la victoria"] = function()
				local session: WaveSession.Session = { wave = WaveRules.MAX_WAVES, remaining = 2, status = "activa" }
				local final, event = WaveSession.mobsKilled(session, 2)
				expect(event == "victoria" and final.status == "victoria", "la 20 acabada es victoria")
			end,

			["si no queda nadie en la arena se pierde"] = function()
				local session, event = WaveSession.playersLeft(started(), 0)
				expect(event == "derrota" and session.status == "derrota", "sin jugadores se pierde")
			end,

			["una partida terminada ya no cambia"] = function()
				local lost, _ = WaveSession.playersLeft(started(), 0)
				local same, event = WaveSession.mobsKilled(lost, 100)
				expect(event == nil and same.status == "derrota" and same.wave == 1, "una partida perdida no avanza")
			end,

			["las oleadas 5, 10 y 15 tienen mini jefe y gema segura"] = function()
				for _, wave in { 5, 10, 15 } do
					local info = WaveRules.info(wave).value
					expect(info.miniBoss and info.safeGem, `la oleada {wave} debe tener mini jefe y gema`)
				end
				expect(not WaveRules.info(4).value.safeGem, "la 4 no tiene gema segura")
			end,

			["la oleada 20 es la final, sin mini jefe"] = function()
				local info = WaveRules.info(20).value
				expect(info.finalBoss and not info.miniBoss, "la 20 es la final")
			end,

			["los jefes de oleada sustituyen al mob fuerte"] = function()
				local mini = WaveRules.info(5).value.mobs
				local final = WaveRules.info(20).value.mobs
				expect(table.find(mini, WaveRules.MINI_BOSS) ~= nil, "la 5 debe traer al capitán")
				expect(table.find(final, WaveRules.FINAL_BOSS) ~= nil, "la 20 debe traer al tirano")
				expect(table.find(final, "ash_brute") == nil, "la 20 no debe traer al bruto de ronda")
				expect(table.find(WaveRules.info(3).value.mobs, WaveRules.MINI_BOSS) == nil, "la 3 no tiene jefe")
			end,

			["todos los mobs de todas las oleadas tienen definición y plantilla"] = function()
				for wave = 1, WaveRules.MAX_WAVES do
					local info = WaveRules.info(wave)
					expect(info.ok, "la oleada " .. wave .. " debe existir")
					for _, mobDefId in info.value.mobs do
						local definition = MobDefs[mobDefId]
						expect(definition ~= nil, "falta la definición de " .. mobDefId)
						expect(definition.templateId == nil or MobDefs[definition.templateId] ~= nil, "plantilla desconocida en " .. mobDefId)
					end
				end
			end,

			["oleadas fuera de rango se rechazan"] = function()
				expect(not WaveRules.info(0).ok, "la 0 no existe")
				expect(not WaveRules.info(21).ok, "la 21 no existe")
				expect(not WaveRules.info(2.5).ok, "no hay medias oleadas")
			end,
		})
	end,
}

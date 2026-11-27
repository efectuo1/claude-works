--!strict
-- Temporizador de pociones: suma del mismo tipo, cola de tipos distintos y multiplicador.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PotionTimer = require(ReplicatedStorage.Shared.Util.PotionTimer)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

local XP_10 = { kind = "xp", multiplier = 2, durationSeconds = 600 }
local XP_15 = { kind = "xp", multiplier = 2, durationSeconds = 900 }
local OTHER_KIND = { kind = "fruta", multiplier = 3, durationSeconds = 300 }
local LUCK = { kind = "luck", multiplier = 1.5, durationSeconds = 300 }

return {
	run = function(): boolean
		return TestHarness.run("PotionTimer", {
			["sin pociones el multiplicador es 1"] = function()
				expect(PotionTimer.multiplier(PotionTimer.new(), 0) == 1, "debe ser 1")
			end,

			["una poción da su multiplicador durante su duración"] = function()
				local state = PotionTimer.new()
				PotionTimer.use(state, 0, XP_10)
				expect(PotionTimer.multiplier(state, 100) == 2, "debe dar x2 a los 100 s")
				expect(PotionTimer.multiplier(state, 601) == 1, "debe acabar a los 600 s")
			end,

			["del mismo tipo se suman las duraciones"] = function()
				local state = PotionTimer.new()
				PotionTimer.use(state, 0, XP_10)
				PotionTimer.use(state, 100, XP_15)
				expect(PotionTimer.endsAt(state, 100) == 1500, "600 + 900 desde el inicio debe terminar en 1500")
				expect(PotionTimer.multiplier(state, 1400) == 2, "sigue activa a los 1400 s")
				expect(PotionTimer.multiplier(state, 1501) == 1, "termina a los 1500 s")
				expect(PotionTimer.queued(state) == 0, "del mismo tipo no hay cola")
			end,

			["otro tipo espera en cola a que termine la activa"] = function()
				local state = PotionTimer.new()
				PotionTimer.use(state, 0, XP_10)
				PotionTimer.use(state, 10, LUCK)
				expect(PotionTimer.queued(state) == 1, "la de suerte debe estar en cola")
				expect(PotionTimer.multiplier(state, 500) == 2, "mientras dura XP, sigue x2")
			end,

			["la cola empieza donde terminó la anterior"] = function()
				local state = PotionTimer.new()
				PotionTimer.use(state, 0, XP_10)
				PotionTimer.use(state, 10, LUCK)
				-- la de suerte dura 300 s desde los 600 s, así que termina en 900
				expect(PotionTimer.multiplier(state, 700) == 1.5, "a los 700 s debe estar activa la de suerte")
				expect(PotionTimer.multiplier(state, 901) == 1, "debe acabar a los 900 s")
				expect(PotionTimer.queued(state) == 0, "la cola debe vaciarse")
			end,

			["si pasa mucho tiempo, la cola se consume en cadena"] = function()
				local state = PotionTimer.new()
				PotionTimer.use(state, 0, XP_10)
				PotionTimer.use(state, 0, LUCK)
				PotionTimer.use(state, 0, XP_15)
				-- la segunda de XP se suma a la activa (0-1500); la de suerte espera y va de 1500 a 1800
				expect(PotionTimer.multiplier(state, 1000) == 2, "a los 1000 s sigue activa la XP sumada")
				expect(PotionTimer.multiplier(state, 1600) == 1.5, "a los 1600 s debe estar activa la de suerte")
				expect(PotionTimer.multiplier(state, 1801) == 1, "todo debe haber terminado a los 1800 s")
			end,

			["guardar y restaurar conserva lo que queda y la cola"] = function()
				local state = PotionTimer.new()
				PotionTimer.use(state, 0, XP_10)
				PotionTimer.use(state, 0, OTHER_KIND)
				local saved = PotionTimer.snapshot(state, 100)
				expect(#saved == 2, "debe guardar la activa y la cola")
				expect(saved[1].seconds == 500, `la activa debe quedar con 500 s y quedan {saved[1].seconds}`)
				expect(saved[2].seconds == 300, "la de la cola debe conservar su duración")

				local restored = PotionTimer.new()
				PotionTimer.restore(restored, 5000, saved)
				expect(PotionTimer.multiplier(restored, 5000) == 2, "la poción restaurada debe estar activa")
				expect(PotionTimer.endsAt(restored, 5000) == 5500, "debe terminar 500 s después de restaurar")
				expect(PotionTimer.queued(restored) == 1, "la otra poción debe quedar en cola")
			end,

			["restaurar una lista vacía deja el estado limpio"] = function()
				local state = PotionTimer.new()
				PotionTimer.use(state, 0, XP_10)
				PotionTimer.restore(state, 0, {})
				expect(PotionTimer.multiplier(state, 0) == 1, "sin datos no debe haber poción activa")
			end,

			["advance no cambia nada antes de tiempo"] = function()
				local state = PotionTimer.new()
				PotionTimer.use(state, 0, XP_10)
				PotionTimer.advance(state, 599)
				expect(state.active ~= nil and state.active.endsAt == 600, "la poción debe seguir activa")
			end,
		})
	end,
}

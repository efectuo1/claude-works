--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Result = require(ReplicatedStorage.Shared.Util.Result)
local ProfileSchema = require(ServerScriptService.Persistence.ProfileSchema)
local ProfileService = require(ServerScriptService.Persistence.ProfileService)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

-- Gateway falso: "storage" simula el DataStore, "locked" las sesiones activas y "onLostByUser" los avisos de robo.
local function newHarness(opts: { leaveOnOpen: boolean? }?)
	local storage: { [string]: unknown } = {}
	local locked: { [string]: boolean } = {}
	local onLostByUser: { [number]: () -> () } = {}
	local lostUsers: { number } = {}
	local present = true
	local leaveOnOpen = opts ~= nil and opts.leaveOnOpen == true

	local gateway: ProfileService.SessionGateway = {
		open = function(userId: number, isCancelled: () -> boolean, onLost: () -> ())
			local key = `user_{userId}`
			if locked[key] then
				return Result.err("session_unavailable")
			end
			if isCancelled() then
				return Result.err("session_unavailable")
			end
			locked[key] = true
			onLostByUser[userId] = onLost
			if leaveOnOpen then
				-- El jugador se va justo después de abrir la sesión.
				present = false
			end
			return Result.ok({
				read = function(): unknown
					return storage[key]
				end,
				write = function(data)
					storage[key] = data
				end,
				close = function()
					locked[key] = nil
				end,
			})
		end,
	}

	local service = ProfileService.new({
		gateway = gateway,
		isPlayerPresent = function(_userId: number): boolean
			return present
		end,
		onSessionLost = function(userId: number)
			table.insert(lostUsers, userId)
		end,
	})

	return {
		service = service,
		storage = storage,
		locked = locked,
		lostUsers = lostUsers,
		-- Simula que otro servidor toma la sesión: la sesión local termina sin que se haya pedido.
		steal = function(userId: number)
			local onLost = onLostByUser[userId]
			if onLost ~= nil then
				onLost()
			end
		end,
	}
end

local function dataOf(service: ProfileService.ProfileService, userId: number): ProfileSchema.ProfileData
	local data = service.get(userId)
	if data == nil then
		error(`no hay perfil cargado para {userId}`, 2)
	end
	return data
end

local function valueOf<T>(result: Result.Result<T>): T
	if not result.ok then
		error(`resultado inesperado: {result.error}`, 2)
	end
	return result.value
end

local function snapshot(level: number, inventory: { [string]: number }): ProfileSchema.ProfileData
	return {
		schemaVersion = ProfileSchema.CURRENT_VERSION,
		contentVersion = ProfileSchema.CONTENT_VERSION,
		level = level,
		xp = 0,
		gold = 0,
		gems = 0,
		rank = "novato",
		inventory = inventory,
		quests = { active = nil, completed = {} },
	}
end

return {
	run = function(): boolean
		return TestHarness.run("ProfileService", {
			["perfil nuevo empieza con valores por defecto"] = function()
				local h = newHarness()
				local loaded = h.service.load(1)
				expect(loaded.ok, "debería cargar un perfil nuevo")
				local data = dataOf(h.service, 1)
				expect(data.level == 1, "nivel inicial 1")
				expect(next(data.inventory) == nil, "inventario vacío")
				expect(h.storage["user_1"] == nil, "cargar no debe escribir")
			end,

			["release guarda el snapshot y la siguiente carga lo recupera"] = function()
				local h = newHarness()
				h.service.load(2)
				local released = h.service.release(2, snapshot(3, { ember_shard = 5 }))
				expect(released.ok, "release debería aceptar un snapshot válido")
				expect(h.locked["user_2"] == nil, "release debe liberar la sesión")

				local reloaded = h.service.load(2)
				expect(reloaded.ok, "debería volver a cargar")
				expect(valueOf(reloaded).level == 3, "el nivel guardado debería persistir")
				expect(valueOf(reloaded).inventory.ember_shard == 5, "el inventario guardado debería persistir")
			end,

			["un perfil corrupto no se carga ni se sobrescribe"] = function()
				local h = newHarness()
				h.storage["user_3"] = "basura"
				local loaded = h.service.load(3)
				expect(not loaded.ok, "un perfil corrupto debe rechazarse")
				expect(h.storage["user_3"] == "basura", "el dato corrupto no debe tocarse")
				expect(h.locked["user_3"] == nil, "la sesión debe cerrarse tras fallar")
			end,

			["un perfil de una versión futura se rechaza sin tocarlo"] = function()
				local h = newHarness()
				h.storage["user_4"] = { schemaVersion = 99, contentVersion = 1, level = 7, inventory = {} }
				local loaded = h.service.load(4)
				expect(not loaded.ok and loaded.error == "profile_from_newer_version", "debe rechazar versión futura")
				expect(h.storage["user_4"] ~= nil, "no debe borrarse")
			end,

			["un snapshot inválido no se escribe pero sí libera la sesión"] = function()
				local h = newHarness()
				h.service.load(5)
				local released = h.service.release(5, snapshot(0, {}))
				expect(not released.ok, "nivel 0 no es válido")
				expect(h.storage["user_5"] == nil, "no debe escribirse un snapshot inválido")
				expect(h.locked["user_5"] == nil, "la sesión debe liberarse igualmente")
			end,

			["un perfil con sesión activa en otro servidor no se abre"] = function()
				local h = newHarness()
				h.locked["user_6"] = true
				local loaded = h.service.load(6)
				expect(not loaded.ok, "no debe abrirse una segunda sesión")
				expect(h.locked["user_6"] == true, "la sesión ajena no debe tocarse")
			end,

			["si el jugador se va durante la carga, la sesión se libera"] = function()
				local h = newHarness({ leaveOnOpen = true })
				local loaded = h.service.load(7)
				expect(not loaded.ok and loaded.error == "player_left", "debe reportar player_left")
				expect(h.locked["user_7"] == nil, "no debe quedar sesión abierta")
				expect(h.service.get(7) == nil, "no debe quedar perfil en memoria")
			end,

			["save intermedio escribe sin liberar la sesión"] = function()
				local h = newHarness()
				h.service.load(8)
				local saved = h.service.save(8, snapshot(2, {}))
				expect(saved.ok, "save debería aceptar un snapshot válido")
				expect(h.locked["user_8"] == true, "save no debe liberar la sesión")
				expect(h.storage["user_8"] ~= nil, "save debe escribir")
				expect(dataOf(h.service, 8).level == 2, "la memoria debe reflejar el guardado")
			end,

			["get devuelve nil si el perfil no está cargado"] = function()
				local h = newHarness()
				expect(h.service.get(9) == nil, "sin carga no hay perfil")
				expect(not h.service.save(9, snapshot(1, {})).ok, "save sin carga debe fallar")
			end,

			["el progreso de misiones sobrevive a un guardado y una carga"] = function()
				local h = newHarness()
				h.service.load(11)
				local data = snapshot(1, {})
				data.quests = { active = { questId = "first_hunt", count = 2 }, completed = { ember_collector = true } }
				expect(h.service.release(11, data).ok, "snapshot con misiones debería guardarse")

				local quests = valueOf(h.service.load(11)).quests
				expect(quests.active ~= nil and quests.active.questId == "first_hunt", "la misión activa debe persistir")
				expect(quests.active ~= nil and quests.active.count == 2, "el progreso debe persistir")
				expect(quests.completed.ember_collector == true, "las misiones completadas deben persistir")
			end,

			["un perfil v1 se migra a v2 con misiones vacías"] = function()
				local h = newHarness()
				h.storage["user_12"] = { schemaVersion = 1, contentVersion = 1, level = 4, inventory = { ember_shard = 2 } }
				local data = valueOf(h.service.load(12))
				expect(data.level == 4, "el nivel de v1 debe conservarse")
				expect(data.inventory.ember_shard == 2, "el inventario de v1 debe conservarse")
				expect(data.schemaVersion == ProfileSchema.CURRENT_VERSION, "debe quedar en la versión actual")
				expect(data.quests.active == nil, "sin misión activa tras migrar")
				expect(next(data.quests.completed) == nil, "sin misiones completadas tras migrar")
			end,

			["si otro servidor roba la sesión, el perfil se descarta, se avisa y no se vuelve a escribir"] = function()
				local h = newHarness()
				h.service.load(13)
				h.steal(13)
				expect(h.service.get(13) == nil, "el perfil robado no debe seguir en memoria")
				expect(#h.lostUsers == 1 and h.lostUsers[1] == 13, "debe avisarse una vez para expulsar")
				local released = h.service.release(13, snapshot(9, {}))
				expect(released.ok and released.value == false, "no debe escribirse tras perder la sesión")
				expect(h.storage["user_13"] == nil, "el dato del otro servidor no debe tocarse")
			end,

			["la liberación normal no dispara el aviso de robo"] = function()
				local h = newHarness()
				h.service.load(14)
				h.service.release(14, nil)
				expect(#h.lostUsers == 0, "una liberación propia no es un robo")
			end,

			["validate rechaza cantidades fraccionarias o negativas en el inventario"] = function()
				local bad = snapshot(1, { ember_shard = 1.5 })
				expect(not ProfileSchema.validate(bad).ok, "cantidad fraccionaria inválida")
				local negative = snapshot(1, { ember_shard = -1 })
				expect(not ProfileSchema.validate(negative).ok, "cantidad negativa inválida")
			end,
		})
	end,
}

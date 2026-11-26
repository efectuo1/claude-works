--!strict
--[[
	Carga, guarda y libera perfiles por jugador. No conoce ProfileStore:
	recibe un "gateway" que abre sesiones exclusivas (ver ProfileStoreGateway).
	Invariantes:
	- Un perfil solo se escribe si pasa la validación.
	- Si la carga falla, la sesión se cierra sin escribir nada.
	- Si el jugador se va durante la carga, la sesión se libera de inmediato.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Shared.Util.Result)
local ProfileSchema = require(script.Parent.ProfileSchema)

export type ProfileData = ProfileSchema.ProfileData

export type Session = {
	read: () -> unknown,
	write: (data: ProfileData) -> (),
	close: () -> (),
}

export type SessionGateway = {
	-- Devuelve err("session_unavailable") si otra sesión tiene el perfil o si isCancelled() es true.
	-- onLost se llama si la sesión termina sin que se haya pedido (otro servidor la tomó).
	open: (userId: number, isCancelled: () -> boolean, onLost: () -> ()) -> Result.Result<Session>,
}

export type Dependencies = {
	gateway: SessionGateway,
	isPlayerPresent: (userId: number) -> boolean,
	onSessionLost: (userId: number) -> (),
}

export type ProfileService = {
	load: (userId: number) -> Result.Result<ProfileData>,
	get: (userId: number) -> ProfileData?,
	save: (userId: number, data: ProfileData) -> Result.Result<boolean>,
	release: (userId: number, finalData: ProfileData?) -> Result.Result<boolean>,
}

-- ticket identifica la sesión concreta: una sesión vieja que termina tarde no debe afectar a una nueva.
type Loaded = { session: Session, data: ProfileData, ticket: {} }

local ProfileService = {}

function ProfileService.new(deps: Dependencies): ProfileService
	local loaded: { [number]: Loaded } = {}

	-- Escribe solo datos válidos. Devuelve err si no lo son y deja el perfil guardado intacto.
	local function writeValidated(entry: Loaded, data: ProfileData): Result.Result<boolean>
		local valid = ProfileSchema.validate(data)
		if not valid.ok then
			return Result.err(valid.error)
		end
		entry.session.write(valid.value)
		entry.data = valid.value
		return Result.ok(true)
	end

	local function release(userId: number, finalData: ProfileData?): Result.Result<boolean>
		local entry = loaded[userId]
		if entry == nil then
			return Result.ok(false)
		end
		loaded[userId] = nil

		local outcome: Result.Result<boolean> = Result.ok(true)
		if finalData ~= nil then
			outcome = writeValidated(entry, finalData)
		end
		entry.session.close()
		return outcome
	end

	local service = {}

	function service.load(userId: number): Result.Result<ProfileData>
		local existing = loaded[userId]
		if existing ~= nil then
			return Result.ok(existing.data)
		end

		local ticket = {}
		local opened = deps.gateway.open(userId, function()
			return not deps.isPlayerPresent(userId)
		end, function()
			local entry = loaded[userId]
			if entry == nil or entry.ticket ~= ticket then
				return -- liberación normal, o sesión ya reemplazada
			end
			-- Sesión robada: se deja de escribir y se avisa para expulsar.
			loaded[userId] = nil
			deps.onSessionLost(userId)
		end)
		if not opened.ok then
			return Result.err(opened.error)
		end
		local session = opened.value

		local raw = session.read()
		local migrated: Result.Result<ProfileData>
		if raw == nil then
			migrated = Result.ok(ProfileSchema.defaults())
		else
			migrated = ProfileSchema.migrate(raw)
		end
		if not migrated.ok then
			session.close()
			return Result.err(migrated.error)
		end

		loaded[userId] = { session = session, data = migrated.value, ticket = ticket }

		if not deps.isPlayerPresent(userId) then
			release(userId, nil)
			return Result.err("player_left")
		end
		return Result.ok(migrated.value)
	end

	function service.get(userId: number): ProfileData?
		local entry = loaded[userId]
		if entry == nil then
			return nil
		end
		return entry.data
	end

	-- Guardado intermedio (autosave): escribe sin liberar la sesión.
	function service.save(userId: number, data: ProfileData): Result.Result<boolean>
		local entry = loaded[userId]
		if entry == nil then
			return Result.err("profile_not_loaded")
		end
		return writeValidated(entry, data)
	end

	service.release = release

	return service
end

return ProfileService

--!strict
--[[
	Adaptador único hacia ProfileStore (librería de terceros, ver docs/ARQUITECTURA.md D3).
	Es el único módulo que conoce la API de la librería. Si cambia la versión, solo cambia este archivo.
	Usa ServerScriptService/Vendor/ProfileStore (ProfileStore 1.0.3, commit 45c9847, Apache-2.0; ver vendor/ProfileStore/NOTICE.txt).
	API verificada contra el código fuente: New, StartSessionAsync (con Cancel), AddUserId, Reconcile, Data, OnSessionEnd, EndSession.
	NO verificado todavía en Studio.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Shared.Util.Result)
local ProfileSchema = require(script.Parent.ProfileSchema)
local ProfileService = require(script.Parent.ProfileService)
local ProfileStoreLib = require(ServerScriptService.Vendor.ProfileStore)

-- Cambiar el nombre implica empezar de cero en el DataStore. Solo con una migración explícita.
local STORE_NAME = "PlayerData_v1"

local function keyFor(userId: number): string
	return `user_{userId}`
end

local ProfileStoreGateway = {}

function ProfileStoreGateway.new(): ProfileService.SessionGateway
	local store = ProfileStoreLib.New(STORE_NAME, ProfileSchema.defaults())

	local gateway = {}

	function gateway.open(
		userId: number,
		isCancelled: () -> boolean,
		onLost: () -> ()
	): Result.Result<ProfileService.Session>
		local profile = store:StartSessionAsync(keyFor(userId), {
			Cancel = isCancelled,
		})
		if profile == nil then
			return Result.err("session_unavailable")
		end

		-- Asociación de UserId para cumplimiento de GDPR (borrado de datos por usuario).
		profile:AddUserId(userId)
		profile:Reconcile()
		-- Dispara también en liberación normal; ProfileService distingue ambos casos.
		profile.OnSessionEnd:Connect(onLost)

		local session = {}

		function session.read(): unknown
			return profile.Data
		end

		-- Se copian los campos en vez de reasignar la tabla, para no romper la referencia de ProfileStore.
		function session.write(data: ProfileSchema.ProfileData)
			local target = profile.Data
			target.schemaVersion = data.schemaVersion
			target.contentVersion = data.contentVersion
			target.level = data.level
			target.xp = data.xp
			target.inventory = data.inventory
			target.quests = data.quests
		end

		function session.close()
			profile:EndSession()
		end

		return Result.ok(session)
	end

	return gateway
end

return ProfileStoreGateway

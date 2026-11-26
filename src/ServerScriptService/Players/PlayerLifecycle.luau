--!strict
--[[
	Ciclo de vida del jugador: carga al entrar, liberación al salir y guardado periódico.
	Recibe todos sus servicios por parámetro. No conoce Remotes ni combate: recibe
	dos callbacks para liberar el estado de combate y de límite de peticiones.
	Un perfil que no carga expulsa al jugador en vez de jugar con valores por defecto,
	para no sobrescribir datos reales.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local PlayerPresence = require(ServerScriptService.Players.PlayerPresence)
local ProfileSchema = require(ServerScriptService.Persistence.ProfileSchema)
local ProfileService = require(ServerScriptService.Persistence.ProfileService)
local InventoryService = require(ServerScriptService.Inventory.InventoryService)
local QuestService = require(ServerScriptService.Quests.QuestService)

export type Deps = {
	players: Players,
	presence: PlayerPresence.Presence,
	profiles: ProfileService.ProfileService,
	inventory: InventoryService.InventoryService,
	quests: QuestService.QuestService,
	releaseCombat: (userId: number) -> (),
	forgetRateLimits: (userId: number) -> (),
	snapshotFor: (userId: number) -> ProfileSchema.ProfileData?,
	autosaveSeconds: number,
	onProfileReady: (player: Player, level: number) -> (),
}

local PlayerLifecycle = {}

function PlayerLifecycle.connect(deps: Deps)
	local presence = deps.presence
	local profiles = deps.profiles

	-- Cierra la sesión sin escribir: el perfil guardado queda intacto.
	local function abandonLoad(player: Player, reason: string, message: string)
		local userId = player.UserId
		warn(`[Profiles] {player.Name}: {reason}`)
		profiles.release(userId, nil)
		deps.inventory.releasePlayer(userId)
		deps.quests.releasePlayer(userId)
		if player.Parent ~= nil then
			player:Kick(message)
		end
	end

	-- Carga: perfil, luego inventario y misiones.
	local function onPlayerAdded(player: Player)
		local userId = player.UserId
		task.spawn(function()
			local loaded = profiles.load(userId)
			if not loaded.ok then
				if loaded.error ~= "player_left" then
					abandonLoad(player, loaded.error, "No pudimos cargar tu perfil. Inténtalo de nuevo en unos minutos.")
				end
				return
			end

			local restoredInventory = deps.inventory.restore(userId, loaded.value.inventory)
			if not restoredInventory.ok then
				abandonLoad(player, `inventario inválido: {restoredInventory.error}`, "Tu inventario no pudo cargarse. Avísanos para revisarlo.")
				return
			end

			local restoredQuests = deps.quests.restore(userId, loaded.value.quests)
			if not restoredQuests.ok then
				abandonLoad(player, `misiones inválidas: {restoredQuests.error}`, "Tu progreso de misiones no pudo cargarse. Avísanos para revisarlo.")
				return
			end

			deps.onProfileReady(player, loaded.value.level)
		end)
	end

	local function onPlayerRemoving(player: Player)
		local userId = player.UserId
		presence.markLeaving(userId)

		deps.releaseCombat(userId)
		deps.forgetRateLimits(userId)

		local released = profiles.release(userId, deps.snapshotFor(userId))
		if not released.ok then
			warn(`[Profiles] guardado rechazado para {player.Name}: {released.error}`)
		end
		deps.inventory.releasePlayer(userId)
		deps.quests.releasePlayer(userId)
	end

	for _, player in deps.players:GetPlayers() do
		onPlayerAdded(player)
	end
	deps.players.PlayerAdded:Connect(onPlayerAdded)
	deps.players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Guardado periódico: limita la pérdida si el servidor se cae a mitad de sesión.
	task.spawn(function()
		while true do
			task.wait(deps.autosaveSeconds)
			for _, player in deps.players:GetPlayers() do
				local snapshot = deps.snapshotFor(player.UserId)
				if snapshot ~= nil then
					local saved = profiles.save(player.UserId, snapshot)
					if not saved.ok then
						warn(`[Profiles] autosave rechazado para {player.Name}: {saved.error}`)
					end
				end
			end
		end
	end)
end

return PlayerLifecycle

--!strict
--[[
	Punto de entrada del servidor (composition root): crea dependencias y conecta Remotes.
	Aquí, y solo aquí, se cablean los servicios entre sí. El ciclo de vida de jugadores
	(carga, salida, autosave) vive en Players/PlayerLifecycle.
	Orden: Remotes primero, después servicios, después jugadores. Nada de esto debe bloquear a los demás.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local ContentValidator = require(Shared.Definitions.ContentValidator)
local Abilities = require(Shared.Definitions.Abilities)
local DropTables = require(Shared.Definitions.DropTables)
local Items = require(Shared.Definitions.Items)
local MobDefs = require(Shared.Definitions.Mobs)
local Quests = require(Shared.Definitions.Quests)
local Zones = require(Shared.Definitions.Zones)

local AbilityService = require(ServerScriptService.Combat.AbilityService)
local DropService = require(ServerScriptService.Drops.DropService)
local KillLootHandler = require(ServerScriptService.Drops.KillLootHandler)
local DomainEvents = require(ServerScriptService.Events.DomainEvents)
local InventoryService = require(ServerScriptService.Inventory.InventoryService)
local MobRegistry = require(ServerScriptService.Mobs.MobRegistry)
local InstanceRouter = require(ServerScriptService.Instances.InstanceRouter)
local instances = InstanceRouter.new(MobRegistry.overworld)
local WorldBootstrap = require(ServerScriptService.World.WorldBootstrap)
local WorldBuilder = require(ServerScriptService.World.WorldBuilder)
local QuestService = require(ServerScriptService.Quests.QuestService)
local RateLimiter = require(ServerScriptService.Infrastructure.RateLimiter)
local ProfileSchema = require(ServerScriptService.Persistence.ProfileSchema)
local ProfileService = require(ServerScriptService.Persistence.ProfileService)
local ProfileStoreGateway = require(ServerScriptService.Persistence.ProfileStoreGateway)
local PlayerPresence = require(ServerScriptService.Players.PlayerPresence)
local PlayerLifecycle = require(ServerScriptService.Players.PlayerLifecycle)
local ProgressionService = require(ServerScriptService.Progression.ProgressionService)
local WalletService = require(ServerScriptService.Economy.WalletService)
local Rewards = require(ReplicatedStorage.Shared.Util.Rewards)
local Contribution = require(ReplicatedStorage.Shared.Util.Contribution)
local Shop = require(ReplicatedStorage.Shared.Definitions.Shop)
local GamePassService = require(ServerScriptService.Monetization.GamePassService)
local MarketplaceService = game:GetService("MarketplaceService")
local WaveService = require(ServerScriptService.Modes.WaveService)
local RouletteService = require(ServerScriptService.Roulette.RouletteService)
local Result = require(Shared.Util.Result)

local AUTOSAVE_SECONDS = 60

-- Contenido roto impide arrancar: es un error de datos, no de partida.
local contentResult = ContentValidator.validate({
	items = Items,
	abilities = Abilities,
	mobs = MobDefs,
	dropTables = DropTables,
	zones = Zones,
	quests = Quests,
})
if not contentResult.ok then
	error(`Contenido inválido: {contentResult.error}`)
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function getPosition(userId: number): Vector3?
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

-- Remotes: contrato mínimo. Se crean primero para que el cliente siempre los encuentre.
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local function createRemote(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local castRemote = createRemote("CastAbility")
local startQuestRemote = createRemote("StartQuest")
local castResultRemote = createRemote("CastResult") -- servidor -> quien lanzó: éxito o motivo del rechazo
local abilityFxRemote = createRemote("AbilityFx") -- servidor -> todos: efecto visual en el objetivo
local rouletteResultRemote = createRemote("RouletteResult") -- servidor -> quien giró: premio o motivo
local walletFxRemote = createRemote("WalletFx") -- servidor -> jugador: ganancias y resultado de rango
local rankUpRemote = createRemote("RankUp") -- jugador -> servidor: pedir subir de rango
local exchangeRemote = createRemote("ExchangeCurrency") -- jugador -> servidor: cambio oro/gemas
local waveFxRemote = createRemote("WaveFx") -- servidor -> jugador: avisos de la modalidad de oleadas

-- Presencia: quién sigue en el servidor y quién se está yendo.
local presence = PlayerPresence.new(function(userId: number)
	return Players:GetPlayerByUserId(userId)
end)

-- Eventos, inventario, misiones y persistencia: un solo punto de creación para todo el servidor.
local events = DomainEvents.create()
local inventory = InventoryService.new(Items)
local profiles = ProfileService.new({
	gateway = ProfileStoreGateway.new(),
	isPlayerPresent = presence.isPresent,
	-- Otro servidor tomó la sesión: el perfil ya no se escribe aquí, así que se expulsa.
	onSessionLost = function(userId: number)
		local player = Players:GetPlayerByUserId(userId)
		warn(`[Profiles] sesión perdida para {userId}`)
		if player ~= nil and not presence.isLeaving(userId) then
			player:Kick("Tu partida se abrió en otro servidor. Vuelve a entrar.")
		end
	end,
})

-- Nivel visible: el servidor lo escribe como atributo; el cliente solo lo lee.
local function setLevelAttribute(userId: number, level: number)
	local player = Players:GetPlayerByUserId(userId)
	if player ~= nil then
		player:SetAttribute("Level", level)
	end
end

local progression = ProgressionService.new({
	getProfile = profiles.get,
	onLevelChanged = setLevelAttribute,
	onXpChanged = function(userId: number, xp: number)
		local player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			player:SetAttribute("Xp", xp)
		end
	end,
})

-- Cada jugador que contribuyó a la baja recibe el XP del mob.
events.mobKilled.connect(function(event)
	local mobDef = MobDefs[event.mobDefId]
	if mobDef == nil then
		return
	end
	for _, userId in event.contributorUserIds do
		local granted = progression.grant(userId, mobDef.xp)
		if not granted.ok then
			warn(`[XP] no se pudo dar XP a {userId}: {granted.error}`)
		end
	end
end)

-- Monedero: oro, gemas y rango. Los atributos los lee la interfaz; el aviso de ganancia va por WalletFx.
local function setWalletAttributes(userId: number, data: { gold: number, gems: number, rank: string })
	local player = Players:GetPlayerByUserId(userId)
	if player ~= nil then
		player:SetAttribute("Gold", data.gold)
		player:SetAttribute("Gems", data.gems)
		player:SetAttribute("Rank", data.rank)
	end
end

-- Pases de Robux: quién los tiene, en memoria. Se pregunta al entrar y tras cada compra.
local ownership = GamePassService.new(GamePassService.robuxCheck(MarketplaceService))

local walletRng = Random.new()
local wallet = WalletService.new({
	getProfile = profiles.get,
	rng = walletRng,
	perksFor = ownership.perksFor,
	onChanged = setWalletAttributes,
	onGranted = function(userId: number, grant: { gold: number, gems: number }, source: string)
		local player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			walletFxRemote:FireClient(player, { kind = "grant", gold = grant.gold, gems = grant.gems, source = source })
		end
	end,
})

-- El oro del mob se tira una vez y se reparte según el daño. Las gemas se tiran por persona.
events.mobKilled.connect(function(event)
	local shares = Contribution.shares(event.damageByUserId, event.contributorUserIds)
	local pool = Rewards.rollMobPool(event.mobDefId, walletRng)
	for _, userId in event.contributorUserIds do
		local reward = wallet.rewardMob(userId, event.mobDefId, shares[userId] or 0, pool)
		if not reward.ok then
			warn(`[Oro] recompensa de mob fallida para {userId}: {reward.error}`)
		end
	end
end)

events.questCompleted.connect(function(event)
	local reward = wallet.rewardQuest(event.userId, event.questId)
	if not reward.ok then
		warn(`[Oro] recompensa de misión fallida para {event.userId}: {reward.error}`)
	end
end)

rankUpRemote.OnServerEvent:Connect(function(player: Player)
	local result = wallet.rankUp(player.UserId)
	if result.ok then
		walletFxRemote:FireClient(player, { kind = "rank", ok = true, rank = result.value })
	else
		walletFxRemote:FireClient(player, { kind = "rank", ok = false, error = result.error })
	end
end)

local function refreshPasses(player: Player)
	ownership.refresh(player.UserId)
	-- Si se fue mientras preguntábamos a Roblox, no guardar sus pases: nadie los iba a liberar.
	if player.Parent == nil then
		ownership.forget(player.UserId)
		return
	end
	for _, pass in Shop.GAMEPASSES do
		player:SetAttribute("Pase_" .. pass.id, ownership.owns(player.UserId, pass.id))
	end
end
Players.PlayerAdded:Connect(function(player: Player)
	task.spawn(refreshPasses, player)
end)
for _, player in Players:GetPlayers() do
	task.spawn(refreshPasses, player)
end
Players.PlayerRemoving:Connect(function(player: Player)
	ownership.forget(player.UserId)
end)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, _gamePassId: number, wasPurchased: boolean)
	if wasPurchased then
		task.spawn(refreshPasses, player)
	end
end)

-- Cambio oro <-> gemas: el servidor valida la petición, limita la frecuencia y aplica el cambio.
local exchangeLimiter = RateLimiter.new(5, 1, os.clock)
exchangeRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	if not exchangeLimiter.allow(player.UserId) then
		walletFxRemote:FireClient(player, { kind = "exchange", ok = false, error = "demasiadas_peticiones" })
		return
	end
	if typeof(payload) ~= "table" or typeof(payload.direction) ~= "string" or typeof(payload.amount) ~= "number" then
		walletFxRemote:FireClient(player, { kind = "exchange", ok = false, error = "payload_invalido" })
		return
	end
	local result = wallet.exchange(player.UserId, payload.direction, payload.amount)
	if result.ok then
		walletFxRemote:FireClient(player, { kind = "exchange", ok = true, gold = result.value.gold, gems = result.value.gems })
	else
		walletFxRemote:FireClient(player, { kind = "exchange", ok = false, error = result.error })
	end
end)

local quests = QuestService.new({
	events = events,
	grantReward = inventory.add,
})

local dropsResult = DropService.new(DropTables, math.random)
if not dropsResult.ok then
	error(`Tablas de drop inválidas: {dropsResult.error}`)
end

KillLootHandler.connect({
	events = events,
	drops = dropsResult.value,
	random = function(): number
		return math.random()
	end,
	luckFor = function(userId: number): number
		local data = profiles.get(userId)
		if data == nil then
			return 0
		end
		return math.min(Rewards.rankOrDefault(data.rank).luck + ownership.perksFor(userId).luck, 0.9)
	end,
	inventory = inventory,
	mobDefs = MobDefs,
})

-- Mundo: primero el mapa mínimo (si falta), luego zonas y mobs.
-- Sin esta llamada no aparece ningún mob (antes se importaba y nunca se arrancaba).
local built = WorldBuilder.build(MobDefs)
if not built.ok then
	warn(`[World] {built.error}`)
end
local world = WorldBootstrap.start(events, serverNow)
if world ~= nil then
	WaveService.new({
		router = instances,
		events = events,
		controller = world.controller,
		templates = world.templates,
		mobsFolder = world.mobsFolder,
		grantGems = function(userId: number, gems: number)
			local granted = wallet.grantGems(userId, gems, "oleadas")
			if not granted.ok then
				warn(`[Oleadas] gemas no entregadas a {userId}: {granted.error}`)
			end
		end,
		grantBoss = function(userId: number)
			local granted = wallet.rewardBoss(userId)
			if not granted.ok then
				warn(`[Oleadas] recompensa de jefe no entregada a {userId}: {granted.error}`)
			end
		end,
		notify = function(userId: number, payload: { [string]: any })
			local player = Players:GetPlayerByUserId(userId)
			if player ~= nil then
				waveFxRemote:FireClient(player, payload)
			end
		end,
	})
end

-- Ruleta del hub: el premio se elige en servidor. La entrega real (monedas, frutas, jutsus) aún no existe:
-- por ahora el premio se muestra y se registra en la consola.
local rouletteLimiter = RateLimiter.new(2, 1, serverNow)
local roulette = RouletteService.new({
	now = serverNow,
	allowRequest = rouletteLimiter.allow,
	random = math.random,
	deliver = function(userId, prize)
		print(`[Ruleta] {userId} obtuvo {prize.label} (entrega pendiente)`)
		return Result.ok(true)
	end,
	cooldownSeconds = 5,
})

local hubFolder = workspace:FindFirstChild("Hub")
local wheel = if hubFolder then hubFolder:FindFirstChild("Ruleta") else nil
if wheel ~= nil and wheel:IsA("BasePart") then
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Girar"
	prompt.ObjectText = "Ruleta"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = wheel
	prompt.Triggered:Connect(function(player: Player)
		local result = roulette.spin(player.UserId)
		if result.ok then
			rouletteResultRemote:FireClient(player, { ok = true, label = result.value.label })
		else
			rouletteResultRemote:FireClient(player, { ok = false, error = result.error })
		end
	end)
else
	warn("[Ruleta] no encuentro workspace.Hub.Ruleta: la ruleta no tiene botón")
end

-- Foto del estado persistente de un jugador. nil si su perfil no está cargado.
local function snapshotFor(userId: number): ProfileSchema.ProfileData?
	local current = profiles.get(userId)
	if current == nil then
		return nil
	end
	return {
		schemaVersion = ProfileSchema.CURRENT_VERSION,
		contentVersion = current.contentVersion,
		level = current.level,
		xp = current.xp,
		gold = current.gold,
		gems = current.gems,
		rank = current.rank,
		inventory = inventory.export(userId),
		quests = quests.export(userId),
	}
end

-- Combate.
local castLimiter = RateLimiter.new(10, 1, serverNow)
local abilities = AbilityService.new({
	now = serverNow,
	allowRequest = castLimiter.allow,
	getLevel = function(userId: number): number?
		local data = profiles.get(userId)
		return if data then data.level else nil
	end,
	getPosition = getPosition,
	registryFor = instances.registryFor,
	schedule = function(seconds: number, fn: () -> ())
		task.delay(seconds, fn)
	end,
})

castRemote.OnServerEvent:Connect(function(player: Player, payload: unknown)
	local result = abilities.cast(player.UserId, payload)
	-- Lectura del payload solo después de que cast lo haya validado.
	local abilityId = if type(payload) == "table" then (payload :: any).abilityId else nil
	if not result.ok then
		castResultRemote:FireClient(player, { ok = false, abilityId = abilityId, error = result.error })
		return
	end
	castResultRemote:FireClient(player, { ok = true, abilityId = abilityId, damage = result.value.damage })
	abilityFxRemote:FireAllClients({ abilityId = abilityId, position = result.value.center })
end)

local questLimiter = RateLimiter.new(2, 1, serverNow)
startQuestRemote.OnServerEvent:Connect(function(player: Player, payload: unknown)
	if not questLimiter.allow(player.UserId) then
		return
	end
	-- Sin perfil cargado, el progreso se sobrescribiría al restaurar: se ignora.
	if profiles.get(player.UserId) == nil then
		return
	end
	if type(payload) ~= "table" then
		return
	end
	local questId = (payload :: { [string]: unknown }).questId
	if type(questId) ~= "string" then
		return
	end
	local result = quests.start(player.UserId, questId)
	if not result.ok then
		print(`[Quests] {player.Name}: {result.error}`)
	end
end)

-- Jugadores: carga al entrar, liberación al salir, guardado periódico.
PlayerLifecycle.connect({
	players = Players,
	presence = presence,
	profiles = profiles,
	inventory = inventory,
	quests = quests,
	releaseCombat = function(userId: number)
		abilities.releasePlayer(userId)
		roulette.releasePlayer(userId)
	end,
	forgetRateLimits = function(userId: number)
		castLimiter.forget(userId)
		questLimiter.forget(userId)
	end,
	snapshotFor = snapshotFor,
	autosaveSeconds = AUTOSAVE_SECONDS,
	-- PlayerLifecycle entrega el Player, no el userId: se escribe el atributo directamente.
	onProfileReady = function(player: Player, level: number)
		player:SetAttribute("Level", level)
		local data = profiles.get(player.UserId)
		player:SetAttribute("Xp", if data then data.xp else 0)
		if data then
			setWalletAttributes(player.UserId, data)
		end
	end,
})

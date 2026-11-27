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
local PotionService = require(ServerScriptService.Potions.PotionService)
local Potions = require(Shared.Definitions.Potions)
local Rewards = require(ReplicatedStorage.Shared.Util.Rewards)
local Contribution = require(ReplicatedStorage.Shared.Util.Contribution)
local Shop = require(ReplicatedStorage.Shared.Definitions.Shop)
local GamePassService = require(ServerScriptService.Monetization.GamePassService)
local MarketplaceService = game:GetService("MarketplaceService")
local WaveService = require(ServerScriptService.Modes.WaveService)
local JefesService = require(ServerScriptService.Modes.JefesService)
local ModeLayout = require(ServerScriptService.World.ModeLayout)
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
local usePotionRemote = createRemote("UsePotion") -- jugador -> servidor: usar una poción de la mochila
local buyPotionRemote = createRemote("BuyPotion") -- jugador -> servidor: comprar una poción con gemas
local backpackRemote = Instance.new("RemoteFunction") -- jugador -> servidor: contenido de la mochila
backpackRemote.Name = "BackpackList"
backpackRemote.Parent = remotes

-- Lista de jefes con requisito para la ventana de modalidades. El cliente la pide al abrirla.
-- El manejador se asigna más abajo, cuando existen perfiles y el servicio de jefes.
local jefesService: any = nil
local waveService: any = nil
local bossListRemote = Instance.new("RemoteFunction")
bossListRemote.Name = "BossList"
bossListRemote.Parent = remotes

-- Premios: estado del regalo diario y del tiempo de juego, y reclamaciones (funciones: el cliente espera la respuesta).
local rewardsStateRemote = Instance.new("RemoteFunction")
rewardsStateRemote.Name = "RewardsState"
rewardsStateRemote.Parent = remotes
local claimDailyRemote = Instance.new("RemoteFunction")
claimDailyRemote.Name = "ClaimDaily"
claimDailyRemote.Parent = remotes
local claimPlaytimeRemote = Instance.new("RemoteFunction")
claimPlaytimeRemote.Name = "ClaimPlaytime"
claimPlaytimeRemote.Parent = remotes

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

bossListRemote.OnServerInvoke = function(player: Player)
	if jefesService == nil then
		return {}
	end
	local data = profiles.get(player.UserId)
	local level = if data then data.level else 0
	local list = {}
	for _, boss in jefesService.list() do
		local def = MobDefs[boss.mobId]
		table.insert(list, {
			id = boss.id,
			name = if def then def.displayName else boss.id,
			minLevel = boss.minLevel,
			locked = level < boss.minLevel,
		})
	end
	return list
end

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

-- Multiplicador de XP por pociones. Se asigna más abajo, cuando existe PotionService.
local potionMultiplier: (number) -> number = function(_userId: number): number
	return 1
end

-- XP extra según la dificultad de la partida en curso (oleadas o jefes). Fuera de partida vale 1.
local function difficultyXpMult(userId: number): number
	if waveService ~= nil and waveService.isInside(userId) then
		return waveService.difficultyMult(userId)
	end
	if jefesService ~= nil and jefesService.isInside(userId) then
		return jefesService.difficultyMult(userId)
	end
	return 1
end

-- Cada jugador que contribuyó a la baja recibe el XP del mob (x pociones x dificultad).
events.mobKilled.connect(function(event)
	local mobDef = MobDefs[event.mobDefId]
	if mobDef == nil then
		return
	end
	for _, userId in event.contributorUserIds do
		local granted = progression.grant(userId, math.floor(mobDef.xp * potionMultiplier(userId) * difficultyXpMult(userId)))
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

-- Pociones: el servidor publica el multiplicador y su fin como atributos para el HUD.
local potions: PotionService.PotionService
local function publishPotion(userId: number)
	local player = Players:GetPlayerByUserId(userId)
	if player ~= nil then
		player:SetAttribute("XpBoostMult", potions.multiplierFor(userId))
		player:SetAttribute("XpBoostEnd", potions.endsAtFor(userId) or 0)
		player:SetAttribute("XpBoostQueue", potions.queuedFor(userId))
	end
end
potions = PotionService.new({
	items = Items,
	inventory = inventory,
	wallet = wallet,
	now = serverNow,
	onChanged = function(userId: number)
		publishPotion(userId)
	end,
})
potionMultiplier = potions.multiplierFor

-- Una poción puede terminar y dar paso a la siguiente de la cola sin que nadie pulse nada:
-- cada segundo se vuelve a publicar el estado. SetAttribute no hace nada si el valor no cambia.
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			publishPotion(player.UserId)
		end
	end
end)

local potionLimiter = RateLimiter.new(4, 1, serverNow)
usePotionRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	if not potionLimiter.allow(player.UserId) then
		walletFxRemote:FireClient(player, { kind = "potion", ok = false, error = "demasiadas_peticiones" })
		return
	end
	if typeof(payload) ~= "table" or typeof(payload.itemId) ~= "string" then
		walletFxRemote:FireClient(player, { kind = "potion", ok = false, error = "payload_invalido" })
		return
	end
	local result = potions.use(player.UserId, payload.itemId)
	if result.ok then
		walletFxRemote:FireClient(player, { kind = "potion", ok = true, endsAt = result.value })
	else
		walletFxRemote:FireClient(player, { kind = "potion", ok = false, error = result.error })
	end
end)

buyPotionRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	if not potionLimiter.allow(player.UserId) then
		walletFxRemote:FireClient(player, { kind = "potion_buy", ok = false, error = "demasiadas_peticiones" })
		return
	end
	if typeof(payload) ~= "table" or typeof(payload.itemId) ~= "string" then
		walletFxRemote:FireClient(player, { kind = "potion_buy", ok = false, error = "payload_invalido" })
		return
	end
	local result = potions.buy(player.UserId, payload.itemId)
	if result.ok then
		walletFxRemote:FireClient(player, { kind = "potion_buy", ok = true, itemId = payload.itemId })
	else
		walletFxRemote:FireClient(player, { kind = "potion_buy", ok = false, error = result.error })
	end
end)

-- Mochila: lo que el jugador tiene, con su botón. Las pociones dicen USAR; el resto, INFO.
backpackRemote.OnServerInvoke = function(player: Player)
	local list = {}
	for itemId, count in inventory.export(player.UserId) do
		local def = Items[itemId]
		if def ~= nil then
			local potion = Potions[itemId]
			table.insert(list, {
				id = itemId,
				name = def.displayName,
				rarity = def.rarity,
				category = def.category,
				count = count,
				desc = if potion then `XP x{potion.multiplier} durante {math.floor(potion.durationSeconds / 60)} min` else "Objeto de la partida",
				use = if potion then "USAR" else "INFO",
				stats = { { "CANTIDAD", tostring(count) } },
			})
		end
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	return list
end

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
	waveService = WaveService.new({
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

	-- Modo jefes: la sala y sus portales están detrás de la arena (ver la posición en Studio).
	jefesService = JefesService.new({
		router = instances,
		events = events,
		controller = world.controller,
		templates = world.templates,
		mobsFolder = world.mobsFolder,
		bossPosition = ModeLayout.bossArenaPosition(),
		exitPosition = ModeLayout.hubSpawn(),
		getLevel = function(userId: number): number?
			local data = profiles.get(userId)
			return if data then data.level else nil
		end,
		grantBoss = function(userId: number)
			local granted = wallet.rewardBoss(userId)
			if not granted.ok then
				warn(`[Jefes] recompensa no entregada a {userId}: {granted.error}`)
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

-- Ir a la entrada de una modalidad desde la ventana de modalidades. El servidor teletransporta.
-- No se permite si el jugador ya está dentro de una partida: primero debe salir.
local goToModeRemote = createRemote("GoToMode")
local goToModeLimiter = RateLimiter.new(3, 1, serverNow)
goToModeRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	if not goToModeLimiter.allow(player.UserId) then
		return
	end
	if typeof(payload) ~= "table" or (payload.mode ~= "wave" and payload.mode ~= "boss") then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if character == nil or root == nil then
		return
	end
	local inside = (waveService ~= nil and waveService.isInside(player.UserId)) or (jefesService ~= nil and jefesService.isInside(player.UserId))
	if inside then
		waveFxRemote:FireClient(player, { kind = "wave_error", error = "en_partida" })
		return
	end
	local destination = if payload.mode == "wave" then ModeLayout.waveLobby() else ModeLayout.bossLobby()
	character:PivotTo(CFrame.new(destination))
	root.AssemblyLinearVelocity = Vector3.zero
end)

-- Ruleta del hub: el premio se elige en servidor y se entrega aquí.
-- Oro y gemas se entregan de verdad. Frutas y jutsus no tienen catálogo todavía: el giro no se gasta.
local rouletteLimiter = RateLimiter.new(2, 1, serverNow)
local roulette = RouletteService.new({
	now = serverNow,
	allowRequest = rouletteLimiter.allow,
	random = math.random,
	deliver = function(userId: number, prize): Result.Result<boolean>
		local granted
		if prize.kind == "gem" then
			granted = wallet.grantGems(userId, prize.amount, "ruleta")
		elseif prize.kind == "gold" then
			granted = wallet.grantGold(userId, prize.amount, "ruleta")
		else
			return Result.err("premio_pendiente")
		end
		if not granted.ok then
			return Result.err(granted.error)
		end
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
		potions = potions.snapshot(userId),
		daily = current.daily,
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

-- ---------- Regalo diario y premios por tiempo ----------
-- Cada premio se entrega en un solo sitio. El ítem va primero: si no cabe, no se entrega nada a medias.
local DailyReward = require(Shared.Util.DailyReward)
local PlaytimeRewards = require(Shared.Util.PlaytimeRewards)
local rewardsLimiter = RateLimiter.new(4, 1, serverNow)
local playtimeStart: { [number]: number } = {}
local playtimeClaimed: { [number]: { [number]: boolean } } = {}

local function grantReward(userId: number, reward: { gold: number?, gems: number?, itemId: string?, quantity: number? }, source: string): Result.Result<boolean>
	if reward.itemId ~= nil then
		local added = inventory.add(userId, reward.itemId, reward.quantity or 1)
		if not added.ok then
			return Result.err(added.error)
		end
	end
	if reward.gold ~= nil then
		local granted = wallet.grantGold(userId, reward.gold, source)
		if not granted.ok then
			return Result.err(granted.error)
		end
	end
	if reward.gems ~= nil then
		local granted = wallet.grantGems(userId, reward.gems, source)
		if not granted.ok then
			return Result.err(granted.error)
		end
	end
	return Result.ok(true)
end

-- Estado para la ventana de premios: racha, si hoy ya se reclamó y minutos de juego seguidos.
local function rewardsState(userId: number)
	local data = profiles.get(userId)
	local today = DailyReward.dayOf(os.time())
	local daily = DailyReward.status(if data then data.daily else DailyReward.empty(), today)
	local start = playtimeStart[userId]
	local elapsed = if start ~= nil then math.max(0, serverNow() - start) else 0
	local claimedList: { number } = {}
	for index in playtimeClaimed[userId] or {} do
		table.insert(claimedList, index)
	end
	return {
		streak = daily.streak,
		nextStreak = daily.nextStreak,
		claimedToday = daily.claimedToday,
		cycleDay = daily.cycleDay,
		elapsed = elapsed,
		claimed = claimedList,
	}
end

rewardsStateRemote.OnServerInvoke = function(player: Player)
	if not rewardsLimiter.allow(player.UserId) then
		return nil
	end
	return rewardsState(player.UserId)
end

claimDailyRemote.OnServerInvoke = function(player: Player)
	if not rewardsLimiter.allow(player.UserId) then
		return { ok = false, error = "demasiadas_peticiones" }
	end
	local data = profiles.get(player.UserId)
	if data == nil then
		return { ok = false, error = "perfil_no_cargado" }
	end
	local claim = DailyReward.claim(data.daily, DailyReward.dayOf(os.time()))
	if not claim.ok then
		return { ok = false, error = claim.error }
	end
	local granted = grantReward(player.UserId, claim.value.reward, "diario")
	if not granted.ok then
		return { ok = false, error = granted.error }
	end
	data.daily = claim.value.state
	return { ok = true, streak = claim.value.streak, reward = claim.value.reward }
end

claimPlaytimeRemote.OnServerInvoke = function(player: Player, index: any)
	if not rewardsLimiter.allow(player.UserId) then
		return { ok = false, error = "demasiadas_peticiones" }
	end
	if typeof(index) ~= "number" then
		return { ok = false, error = "payload_invalido" }
	end
	local start = playtimeStart[player.UserId]
	if start == nil then
		return { ok = false, error = "perfil_no_cargado" }
	end
	local claimed = playtimeClaimed[player.UserId] or {}
	playtimeClaimed[player.UserId] = claimed
	local result = PlaytimeRewards.claim(index, serverNow() - start, claimed)
	if not result.ok then
		return { ok = false, error = result.error }
	end
	local granted = grantReward(player.UserId, result.value, "tiempo")
	if not granted.ok then
		claimed[index] = nil -- no se gasta el hito si el premio no se pudo entregar
		return { ok = false, error = granted.error }
	end
	return { ok = true, reward = result.value }
end

-- Jugadores: carga al entrar, liberación al salir, guardado periódico.
PlayerLifecycle.connect({
	players = Players,
	presence = presence,
	profiles = profiles,
	inventory = inventory,
	quests = quests,
	releaseCombat = function(userId: number)
		abilities.releasePlayer(userId)
		potions.releasePlayer(userId)
		roulette.releasePlayer(userId)
		playtimeStart[userId] = nil
		playtimeClaimed[userId] = nil
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
			-- Las pociones que quedaban al salir siguen con el tiempo que les quedaba.
			potions.restore(player.UserId, data.potions)
			publishPotion(player.UserId)
		end
		-- El tiempo de juego cuenta desde que el perfil está listo.
		playtimeStart[player.UserId] = serverNow()
		playtimeClaimed[player.UserId] = {}
	end,
})

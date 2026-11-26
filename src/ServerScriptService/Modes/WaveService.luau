--!strict
--[[
	Modalidad de oleadas en la arena. Une WaveSession (reglas puras) con el mundo:
	- Un portal (ProximityPrompt) en la arena: de 1 a 4 jugadores entran a la misma partida.
	- Los mobs de cada oleada se crean como los de zona, pero sin respawn: cuentan para la oleada.
	- Cada muerte pasa por mobKilled, así que XP, oro y objetos funcionan igual que en el mapa.
	Una partida a la vez en el servidor. Las pruebas de reglas están en WaveSession.spec.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local MobDefs = require(ReplicatedStorage.Shared.Definitions.Mobs)
local Result = require(ReplicatedStorage.Shared.Util.Result)
local WaveRules = require(ReplicatedStorage.Shared.Util.WaveRules)
local WaveSession = require(ReplicatedStorage.Shared.Util.WaveSession)
local DomainEvents = require(ServerScriptService.Events.DomainEvents)
local Mob = require(ServerScriptService.Mobs.Mob)
local MobController = require(ServerScriptService.Mobs.MobController)
local MobRegistry = require(ServerScriptService.Mobs.MobRegistry)
local MapLayout = require(ServerScriptService.World.MapLayout)
local InstanceRouter = require(ServerScriptService.Instances.InstanceRouter)

export type Dependencies = {
	events: DomainEvents.Events,
	controller: MobController.Dependencies,
	templates: Instance,
	mobsFolder: Instance,
	grantGems: (userId: number, gems: number) -> (),
	grantBoss: (userId: number) -> (),
	notify: (userId: number, payload: { [string]: any }) -> (),
	router: InstanceRouter.InstanceRouter?,
}

type MobEntry = { model: Model, controller: MobController.Controller? }
type Run = {
	id: string,
	session: WaveSession.Session,
	players: { [number]: boolean },
	mobs: { [string]: MobEntry },
	registry: MobRegistry.Registry,
	healthMult: number,
}

local MAX_PLAYERS = 4
local NEXT_WAVE_DELAY = 3 -- segundos entre oleadas
local RING_RADIUS = 18 -- los mobs aparecen en un anillo dentro de la arena
local SPAWN_LIFT = 3
local HUB_POSITION = Vector3.new(0, 6, 0)

-- Dificultad elegida al entrar. Provisional: se ajusta con las pruebas.
local DIFFICULTY = { normal = 1, dificil = 1.5, pesadilla = 2 }
-- Cada ronda tiene un poco más de vida que la anterior.
local WAVE_STEP = 0.05

local function healthMult(difficulty: number, wave: number): number
	return difficulty * (1 + WAVE_STEP * (wave - 1))
end

local runCounter = 0

local WaveService = {}

local function arenaCenter(): Vector3
	local region = MapLayout.region("modes")
	local center = if region then region.center else Vector2.zero
	return Vector3.new(center.X, MapLayout.height(center.X, center.Y) + 4, center.Y)
end

-- Oleada con jefe (mini o final): el marcador lo dice.
local function isBossWave(wave: number): boolean
	local info = WaveRules.info(wave)
	if not info.ok then
		return false
	end
	return info.value.miniBoss or info.value.finalBoss
end

local function countPlayers(run: Run): number
	local n = 0
	for _ in run.players do
		n += 1
	end
	return n
end

local function fadeAndRemove(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			TweenService:Create(descendant, TweenInfo.new(0.8), { Transparency = 1 }):Play()
		elseif descendant:IsA("Highlight") or descendant:IsA("BillboardGui") then
			(descendant :: any).Enabled = false
		end
	end
	task.delay(1, function()
		model:Destroy()
	end)
end

local function teleport(userId: number, position: Vector3)
	local player = Players:GetPlayerByUserId(userId)
	local character = if player then player.Character else nil
	if character ~= nil then
		character:PivotTo(CFrame.new(position))
	end
end

function WaveService.new(deps: Dependencies)
	local run: Run? = nil
	local spawnWave: (Run, number) -> ()
	local finish: (Run, string) -> ()
	local leave: (number) -> ()

	-- Comprueba que todas las oleadas tienen definición y plantilla antes de empezar: así nunca se queda una oleada a medias.
	local function canSpawnAll(): boolean
		for wave = 1, WaveRules.MAX_WAVES do
			local info = WaveRules.info(wave)
			if not info.ok then
				return false
			end
			for _, mobDefId in info.value.mobs do
				local definition = MobDefs[mobDefId]
				if definition == nil or deps.templates:FindFirstChild(definition.templateId or mobDefId) == nil then
					warn(`[Oleadas] falta definición o plantilla de {mobDefId}`)
					return false
				end
			end
		end
		return true
	end

	local function watchDeath(userId: number)
		local player = Players:GetPlayerByUserId(userId)
		local character = if player then player.Character else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid ~= nil then
			humanoid.Died:Connect(function()
				leave(userId)
			end)
		end
	end

	local function notifyAll(current: Run, payload: { [string]: any })
		for userId in current.players do
			deps.notify(userId, payload)
		end
	end

	local function onMobKilled(current: Run, instanceId: string, event: DomainEvents.MobKilledEvent)
		local entry = current.mobs[instanceId]
		current.mobs[instanceId] = nil
		current.registry.unregister(instanceId)
		if entry ~= nil then
			if entry.controller ~= nil then
				entry.controller.stop()
			end
			fadeAndRemove(entry.model)
		end
		deps.events.mobKilled.fire(event)

		if run ~= current then
			return -- la partida ya terminó: el reparto de esta muerte ya está hecho
		end
		local clearedWave = current.session.wave
		local nextSession, change = WaveSession.mobsKilled(current.session, 1)
		current.session = nextSession
		if change == "oleada_superada" then
			local cleared = WaveRules.info(clearedWave)
			if cleared.ok and cleared.value.safeGem then
				for userId in current.players do
					deps.grantGems(userId, 1)
				end
			end
			notifyAll(current, { kind = "wave", wave = nextSession.wave, total = WaveRules.MAX_WAVES, boss = isBossWave(nextSession.wave) })
			task.delay(NEXT_WAVE_DELAY, function()
				if run == current then
					spawnWave(current, current.session.wave)
				end
			end)
		elseif change == "victoria" then
			finish(current, "victoria")
		end
	end

	spawnWave = function(current: Run, wave: number)
		local info = WaveRules.info(wave)
		if not info.ok then
			return
		end
		local mobIds = info.value.mobs
		local center = arenaCenter()
		for index, mobDefId in mobIds do
			local baseDefinition = MobDefs[mobDefId]
			local template = deps.templates:FindFirstChild(baseDefinition and (baseDefinition.templateId or mobDefId) or mobDefId) :: Model?
			if baseDefinition == nil or template == nil then
				finish(current, "error")
				return
			end
			local definition = table.clone(baseDefinition)
			definition.maxHealth = math.floor(baseDefinition.maxHealth * healthMult(current.healthMult, wave))
			local angle = (index - 1) / #mobIds * math.pi * 2
			local x = center.X + math.cos(angle) * RING_RADIUS
			local z = center.Z + math.sin(angle) * RING_RADIUS
			local home = Vector3.new(x, MapLayout.height(x, z) + SPAWN_LIFT, z)
			local instanceId = `oleada_{wave}_{index}`

			local model = template:Clone()
			model.Name = instanceId
			model:SetAttribute("DisplayName", definition.displayName)
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid ~= nil then
				humanoid.MaxHealth = definition.maxHealth
				humanoid.Health = definition.maxHealth
			end
			model:PivotTo(CFrame.new(home))
			model.Parent = deps.mobsFolder

			local entry: MobEntry = { model = model, controller = nil }
			current.mobs[instanceId] = entry
			local mob = Mob.new(instanceId, definition, home, function(event)
				if humanoid ~= nil then
					humanoid.Health = 0
				end
				onMobKilled(current, instanceId, event)
			end, function(health: number)
				if humanoid ~= nil then
					humanoid.Health = health
				end
			end)
			local started = MobController.start(model, mob, definition, home, deps.controller)
			if not started.ok then
				warn(`[Oleadas] {instanceId}: {started.error}`)
				model:Destroy()
				current.mobs[instanceId] = nil
				finish(current, "error")
				return
			end
			entry.controller = started.value
			current.registry.register(instanceId, mob)
		end
	end

	finish = function(current: Run, result: string)
		if run ~= current then
			return
		end
		run = nil
		for instanceId, entry in current.mobs do
			current.registry.unregister(instanceId)
			if entry.controller ~= nil then
				entry.controller.stop()
			end
			entry.model:Destroy()
		end
		current.mobs = {}
		if deps.router then
			deps.router.destroy(current.id)
		end
		for userId in current.players do
			if result == "victoria" then
				deps.grantBoss(userId)
			end
			deps.notify(userId, { kind = "end", result = result, wave = current.session.wave })
			teleport(userId, HUB_POSITION)
		end
	end

	leave = function(userId: number)
		local current = run
		if current == nil or not current.players[userId] then
			return
		end
		current.players[userId] = nil
		if deps.router then
			deps.router.leave(userId)
		end
		deps.notify(userId, { kind = "end", result = "salida", wave = current.session.wave })
		teleport(userId, HUB_POSITION)
		if countPlayers(current) == 0 then
			finish(current, "derrota")
		end
	end

	local service = {}

	-- Entra a la arena. La primera persona abre la partida; las siguientes se unen si hay sitio.
	function service.enter(userId: number, difficulty: string?): Result.Result<boolean>
		local current = run
		if current ~= nil then
			if current.players[userId] then
				return Result.err("ya_estas_dentro")
			end
			if countPlayers(current) >= MAX_PLAYERS then
				return Result.err("arena_llena")
			end
			current.players[userId] = true
			if deps.router then
				deps.router.enter(userId, current.id)
			end
			teleport(userId, arenaCenter())
			watchDeath(userId)
			deps.notify(userId, { kind = "wave", wave = current.session.wave, total = WaveRules.MAX_WAVES, boss = isBossWave(current.session.wave) })
			return Result.ok(true)
		end

		local multiplier = DIFFICULTY[difficulty or "normal"]
		if multiplier == nil then
			return Result.err("dificultad_invalida")
		end
		if not canSpawnAll() then
			return Result.err("faltan_plantillas")
		end
		local session = WaveSession.start()
		if not session.ok then
			return Result.err(session.error)
		end
		runCounter += 1
		local registry = MobRegistry.new()
		local opened: Run = {
			id = `partida_{runCounter}`,
			session = session.value,
			players = { [userId] = true },
			mobs = {},
			registry = registry,
			healthMult = multiplier,
		}
		run = opened
		if deps.router then
			deps.router.create(opened.id, registry)
			deps.router.enter(userId, opened.id)
		end
		teleport(userId, arenaCenter())
		watchDeath(userId)
		notifyAll(opened, { kind = "wave", wave = 1, total = WaveRules.MAX_WAVES, boss = isBossWave(1) })
		spawnWave(opened, 1)
		return Result.ok(true)
	end

	service.leave = leave

	-- Un portal por dificultad, en fila delante de la arena. Cada uno es un ProximityPrompt del servidor.
	local LABELS = { normal = "Normal", dificil = "Difícil", pesadilla = "Pesadilla" }
	local ORDER = { "normal", "dificil", "pesadilla" }
	for index, key in ORDER do
		local portal = Instance.new("Part")
		portal.Name = "Portal_" .. key
		portal.Anchored = true
		portal.CanCollide = false
		portal.Transparency = 1
		portal.Size = Vector3.new(2, 2, 2)
		portal.Position = arenaCenter() + Vector3.new(-8 + (index - 1) * 8, -2, 26) -- a la altura de los pies, para que el prompt alcance
		portal.Parent = workspace

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Entrar: " .. LABELS[key]
		prompt.ObjectText = "Oleadas"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 14
		prompt.Parent = portal
		prompt.Triggered:Connect(function(player: Player)
			local result = service.enter(player.UserId, key)
			if not result.ok then
				deps.notify(player.UserId, { kind = "wave_error", error = result.error })
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		leave(player.UserId)
	end)

	return service
end

return WaveService

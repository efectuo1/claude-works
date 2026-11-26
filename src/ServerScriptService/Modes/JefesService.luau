--!strict
--[[
	Modalidad de jefes. Un jefe a la vez, en su propia partida con registro de mobs propio.
	- Se elige jefe y dificultad al entrar. Cada jugador necesita el nivel mínimo del jefe.
	- Hasta 4 jugadores. Si el jefe muere, todos ganan la recompensa de jefe.
	- Si no queda nadie dentro, la partida se cierra.
	Los jefes provisionales son los de oleadas; los de One Piece y Naruto se añaden a BOSSES.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MobDefs = require(ReplicatedStorage.Shared.Definitions.Mobs)
local Result = require(ReplicatedStorage.Shared.Util.Result)
local DomainEvents = require(ServerScriptService.Events.DomainEvents)
local Mob = require(ServerScriptService.Mobs.Mob)
local MobController = require(ServerScriptService.Mobs.MobController)
local MobRegistry = require(ServerScriptService.Mobs.MobRegistry)
local InstanceRouter = require(ServerScriptService.Instances.InstanceRouter)

export type Boss = { id: string, mobId: string, minLevel: number }

export type Dependencies = {
	events: DomainEvents.Events,
	controller: MobController.Dependencies,
	templates: Instance,
	mobsFolder: Instance,
	bossPosition: Vector3,
	portalPosition: Vector3,
	exitPosition: Vector3, -- a dónde vuelve quien sale de la sala de jefes
	getLevel: (userId: number) -> number?,
	grantBoss: (userId: number) -> (),
	notify: (userId: number, payload: { [string]: any }) -> (),
	router: InstanceRouter.InstanceRouter?,
}

-- Jefes elegibles. minLevel es provisional hasta que se definan los niveles.
local BOSSES: { Boss } = {
	{ id = "ember_tyrant", mobId = "ember_tyrant", minLevel = 10 },
	{ id = "ash_captain", mobId = "ash_captain", minLevel = 5 },
}

local DIFFICULTY = { normal = 1, dificil = 1.5, pesadilla = 2 }
local MAX_PLAYERS = 4

type Run = {
	id: string,
	boss: Boss,
	players: { [number]: boolean },
	registry: MobRegistry.Registry,
	healthMult: number,
	mobInstanceId: string?,
	model: Model?,
	controller: MobController.Controller?,
}

local JefesService = {}
local runCounter = 0

function JefesService.new(deps: Dependencies)
	local run: Run? = nil

	local function teleport(userId: number, position: Vector3)
		local player = Players:GetPlayerByUserId(userId)
		local character = if player then player.Character else nil
		if character ~= nil then
			character:PivotTo(CFrame.new(position))
		end
	end

	local function countPlayers(current: Run): number
		local n = 0
		for _ in current.players do
			n += 1
		end
		return n
	end

	local finish: (Run, string) -> ()

	local function onBossKilled(current: Run, event: DomainEvents.MobKilledEvent)
		if run ~= current then
			return
		end
		current.registry.unregister(current.mobInstanceId or "")
		if current.controller ~= nil then
			current.controller.stop()
		end
		deps.events.mobKilled.fire(event)
		finish(current, "victoria")
	end

	local function spawnBoss(current: Run)
		local baseDefinition = MobDefs[current.boss.mobId]
		local template = if baseDefinition then deps.templates:FindFirstChild(baseDefinition.templateId or current.boss.mobId) :: Model? else nil
		if baseDefinition == nil or template == nil then
			warn(`[Jefes] falta definición o plantilla de {current.boss.mobId}`)
			finish(current, "error")
			return
		end

		local definition = table.clone(baseDefinition)
		definition.maxHealth = math.floor(baseDefinition.maxHealth * current.healthMult)
		local home = deps.bossPosition
		local instanceId = `jefe_{current.id}`

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

		current.mobInstanceId = instanceId
		current.model = model
		local mob = Mob.new(instanceId, definition, home, function(event)
			if humanoid ~= nil then
				humanoid.Health = 0
			end
			onBossKilled(current, event)
		end, function(health: number)
			if humanoid ~= nil then
				humanoid.Health = health
			end
		end)
		local started = MobController.start(model, mob, definition, home, deps.controller)
		if not started.ok then
			warn(`[Jefes] {instanceId}: {started.error}`)
			model:Destroy()
			finish(current, "error")
			return
		end
		current.controller = started.value
		current.registry.register(instanceId, mob)
	end

	finish = function(current: Run, result: string)
		if run ~= current then
			return
		end
		run = nil
		if current.mobInstanceId then
			current.registry.unregister(current.mobInstanceId)
		end
		if current.controller ~= nil then
			current.controller.stop()
		end
		if current.model ~= nil then
			current.model:Destroy()
		end
		if deps.router then
			deps.router.destroy(current.id)
		end
		for userId in current.players do
			if result == "victoria" then
				deps.grantBoss(userId)
			end
			deps.notify(userId, { kind = "end", result = result, boss = current.boss.id })
			teleport(userId, deps.bossPosition + Vector3.new(0, 0, -20))
		end
	end

	local service = {}

	-- Lista de jefes con su requisito, para que la interfaz muestre los bloqueados.
	function service.list(): { Boss }
		return BOSSES
	end

	-- Entra a un jefe. La primera persona abre la partida; las siguientes se unen con el mismo jefe.
	function service.enter(userId: number, bossId: string, difficulty: string?): Result.Result<boolean>
		local boss: Boss? = nil
		for _, candidate in BOSSES do
			if candidate.id == bossId then
				boss = candidate
			end
		end
		if boss == nil then
			return Result.err("jefe_desconocido")
		end
		local level = deps.getLevel(userId)
		if level == nil or level < boss.minLevel then
			return Result.err("nivel_insuficiente")
		end
		local multiplier = DIFFICULTY[difficulty or "normal"]
		if multiplier == nil then
			return Result.err("dificultad_invalida")
		end

		local current = run
		if current ~= nil then
			if current.boss.id ~= bossId then
				return Result.err("otro_jefe_en_curso")
			end
			if current.players[userId] then
				return Result.err("ya_estas_dentro")
			end
			if countPlayers(current) >= MAX_PLAYERS then
				return Result.err("partida_llena")
			end
			current.players[userId] = true
			if deps.router then
				deps.router.enter(userId, current.id)
			end
			teleport(userId, deps.bossPosition + Vector3.new(0, 0, -20))
			return Result.ok(true)
		end

		runCounter += 1
		local registry = MobRegistry.new()
		local opened: Run = {
			id = `jefes_{runCounter}`,
			boss = boss,
			players = { [userId] = true },
			registry = registry,
			healthMult = multiplier,
		}
		run = opened
		if deps.router then
			deps.router.create(opened.id, registry)
			deps.router.enter(userId, opened.id)
		end
		teleport(userId, deps.bossPosition + Vector3.new(0, 0, -20))
		spawnBoss(opened)
		return Result.ok(true)
	end

	-- Salir: el jugador vuelve al mundo; si queda sin nadie, la partida se cierra.
	function service.leave(userId: number)
		local current = run
		if current == nil or not current.players[userId] then
			return
		end
		current.players[userId] = nil
		if deps.router then
			deps.router.leave(userId)
		end
		deps.notify(userId, { kind = "end", result = "salida", boss = current.boss.id })
		teleport(userId, deps.exitPosition)
		if countPlayers(current) == 0 then
			finish(current, "derrota")
		end
	end

	-- Un portal por jefe y dificultad, en filas delante de la sala de jefes.
	local LABELS = { normal = "Normal", dificil = "Difícil", pesadilla = "Pesadilla" }
	local ORDER = { "normal", "dificil", "pesadilla" }
	for row, boss in BOSSES do
		for col, key in ORDER do
			local portal = Instance.new("Part")
			portal.Name = `PortalJefe_{boss.id}_{key}`
			portal.Anchored = true
			portal.CanCollide = false
			portal.Transparency = 1
			portal.Size = Vector3.new(2, 2, 2)
			portal.Position = deps.portalPosition + Vector3.new((col - 1) * 8 - 8, -2, (row - 1) * 10)
			portal.Parent = workspace

			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = `Retar: {boss.id} ({LABELS[key]})`
			prompt.ObjectText = "Jefes"
			prompt.HoldDuration = 0.4
			prompt.MaxActivationDistance = 14
			prompt.Parent = portal
			prompt.Triggered:Connect(function(player: Player)
				local result = service.enter(player.UserId, boss.id, key)
				if not result.ok then
					deps.notify(player.UserId, { kind = "wave_error", error = result.error })
				end
			end)
		end
	end

	-- Salida: un portal al lado de la entrada. Solo actúa a quien está dentro de una sala.
	local exitPart = Instance.new("Part")
	exitPart.Name = "SalidaJefes"
	exitPart.Anchored = true
	exitPart.CanCollide = false
	exitPart.Transparency = 1
	exitPart.Size = Vector3.new(2, 2, 2)
	exitPart.Position = deps.portalPosition + Vector3.new(0, -2, -6)
	exitPart.Parent = workspace

	local exitPrompt = Instance.new("ProximityPrompt")
	exitPrompt.ActionText = "Salir de la sala"
	exitPrompt.ObjectText = "Jefes"
	exitPrompt.HoldDuration = 0.4
	exitPrompt.MaxActivationDistance = 14
	exitPrompt.Parent = exitPart
	exitPrompt.Triggered:Connect(function(player: Player)
		service.leave(player.UserId)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		service.leave(player.UserId)
	end)

	return service
end

return JefesService

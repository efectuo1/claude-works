--!strict
--[[
	Aparece y reaparece mobs de una zona. Usa SpawnPlanner para validar y planificar,
	y gestiona Instances, registro de objetivos y respawn al morir.
	Todas las dependencias de Roblox entran por parámetro.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage.Shared
local MobDefs = require(Shared.Definitions.Mobs)
local ZoneDefs = require(Shared.Definitions.Zones)
local Result = require(Shared.Util.Result)
local DomainEvents = require(script.Parent.Parent.Events.DomainEvents)
local Mob = require(script.Parent.Mob)
local MobController = require(script.Parent.MobController)
local MobRegistry = require(script.Parent.MobRegistry)
local SpawnPlanner = require(script.Parent.SpawnPlanner)

export type Dependencies = {
	events: DomainEvents.Events,
	templates: Instance, -- ServerStorage.MobTemplates: un Model por mobDef con el mismo nombre
	mobsFolder: Instance, -- workspace.Mobs
	zonesFolder: Instance, -- workspace.Zones
	controller: MobController.Dependencies,
}

export type MobSpawner = {
	startZone: (zoneId: string) -> Result.Result<boolean>,
}

local MobSpawner = {}

-- Coste visual: los mobs son provisionales y no necesitan sombra proyectada.
-- Quitarla reduce trabajo de render por cada mob clonado.
local function lighten(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CastShadow = false
		end
	end
end

-- Desaparición suave al morir: el zombi se vuelve transparente y se apagan su contorno y su nombre.
local function fadeOut(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			TweenService:Create(descendant :: BasePart, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		elseif descendant:IsA("Highlight") or descendant:IsA("BillboardGui") then
			(descendant :: any).Enabled = false
		end
	end
end

function MobSpawner.new(deps: Dependencies): MobSpawner
	local spawnSlot: (slot: SpawnPlanner.SpawnSlot, spawnFolder: Instance) -> ()

	spawnSlot = function(slot: SpawnPlanner.SpawnSlot, spawnFolder: Instance)
		local definition = MobDefs[slot.mobDefId]
		local point = spawnFolder:FindFirstChild(slot.spawnPointName) :: BasePart?
		local template = deps.templates:FindFirstChild(definition.id) :: Model?
		if point == nil or template == nil then
			warn(`[MobSpawner] falta punto o plantilla para {slot.instanceId}`)
			return
		end

		local model = template:Clone()
		model.Name = slot.instanceId
		-- Nombre que ve el jugador (el Name es un id interno de spawn).
		model:SetAttribute("DisplayName", definition.displayName)
		lighten(model)
		-- La vida del servidor se refleja en el Humanoid: el cliente la usa para descartar mobs muertos.
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid ~= nil then
			humanoid.MaxHealth = definition.maxHealth
			humanoid.Health = definition.maxHealth
		end
		model:PivotTo(point.CFrame)
		model.Parent = deps.mobsFolder

		local home = point.Position
		local controller: MobController.Controller? = nil

		local mob = Mob.new(slot.instanceId, definition, home, function(event)
			MobRegistry.unregister(slot.instanceId)
			if humanoid ~= nil then
				humanoid.Health = 0
			end
			fadeOut(model)
			if controller ~= nil then
				controller.stop()
			end
			deps.events.mobKilled.fire(event)
			task.delay(slot.respawnSeconds, function()
				model:Destroy()
				spawnSlot(slot, spawnFolder)
			end)
		end, function(health: number)
			if humanoid ~= nil then
				humanoid.Health = health
			end
		end)

		local started = MobController.start(model, mob, definition, home, deps.controller)
		if not started.ok then
			-- Un fallo al arrancar no debe dejar el hueco vacío para siempre: se reintenta.
			warn(`[MobSpawner] {slot.instanceId}: {started.error}`)
			model:Destroy()
			task.delay(slot.respawnSeconds, function()
				spawnSlot(slot, spawnFolder)
			end)
			return
		end
		controller = started.value
		MobRegistry.register(slot.instanceId, mob)
	end

	local service = {}

	function service.startZone(zoneId: string): Result.Result<boolean>
		local zone = ZoneDefs[zoneId]
		if zone == nil then
			return Result.err(`zona desconocida: {zoneId}`)
		end

		local planned = SpawnPlanner.plan(zone)
		if not planned.ok then
			return Result.err(planned.error)
		end

		local zoneFolder = deps.zonesFolder:FindFirstChild(zoneId)
		local spawnFolder = if zoneFolder then zoneFolder:FindFirstChild("Spawns") else nil
		if spawnFolder == nil then
			return Result.err(`falta workspace.Zones.{zoneId}.Spawns`)
		end

		for _, slot in planned.value do
			spawnSlot(slot, spawnFolder)
		end
		return Result.ok(true)
	end

	return service
end

return MobSpawner

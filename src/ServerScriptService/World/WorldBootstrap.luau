--!strict
--[[
	Arranque del mundo: zonas, mobs y las consultas que los mobs necesitan sobre jugadores.
	Si falta algo en Studio se avisa y el servidor sigue funcionando sin mobs (ver docs/ARQUITECTURA.md §6.1).
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DomainEvents = require(ServerScriptService.Events.DomainEvents)
local MobController = require(ServerScriptService.Mobs.MobController)
local MobSpawner = require(ServerScriptService.Mobs.MobSpawner)

local WorldBootstrap = {}

export type Context = {
	controller: MobController.Dependencies,
	templates: Instance,
	mobsFolder: Instance,
}

local function findNearestPlayer(position: Vector3, range: number): MobController.Target?
	local best: MobController.Target? = nil
	local bestDistance = range
	for _, player in Players:GetPlayers() do
		local root = (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) :: BasePart?
		if root ~= nil then
			-- Distancia horizontal: la altura no debe decidir si un jugador está al alcance.
			local delta = root.Position - position
			local distance = Vector2.new(delta.X, delta.Z).Magnitude
			if distance <= bestDistance then
				bestDistance = distance
				best = { userId = player.UserId, position = root.Position }
			end
		end
	end
	return best
end

local function damagePlayer(userId: number, amount: number)
	local player = Players:GetPlayerByUserId(userId)
	if player == nil then
		return
	end
	local character = player.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid:TakeDamage(amount)
	end
end


function WorldBootstrap.start(events: DomainEvents.Events, serverNow: () -> number): Context?
	local mobTemplates = ServerStorage:FindFirstChild("MobTemplates")
	local mobsFolder = workspace:FindFirstChild("Mobs")
	local zonesFolder = workspace:FindFirstChild("Zones")
	if mobTemplates == nil or mobsFolder == nil or zonesFolder == nil then
		warn("[World] faltan ServerStorage.MobTemplates, workspace.Mobs o workspace.Zones: no aparecerán mobs (ver docs/ARQUITECTURA.md §6.1)")
		return nil
	end

	local controller: MobController.Dependencies = {
		now = serverNow,
		findNearestTarget = findNearestPlayer,
		damageTarget = damagePlayer,
	}
	local spawner = MobSpawner.new({
		events = events,
		templates = mobTemplates,
		mobsFolder = mobsFolder,
		zonesFolder = zonesFolder,
		controller = controller,
	})

	local zoneResult = spawner.startZone("starter_ember_fields")
	if not zoneResult.ok then
		warn(`[Zones] no se pudo iniciar la zona: {zoneResult.error}`)
	end
	-- Aviso de diagnóstico: cuántos mobs existen de verdad en workspace.Mobs.
	task.delay(3, function()
		print(`[World] mobs en workspace.Mobs: {#mobsFolder:GetChildren()}`)
	end)

	return { controller = controller, templates = mobTemplates, mobsFolder = mobsFolder }
end



return WorldBootstrap

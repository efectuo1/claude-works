--!strict
--[[
	Movimiento de mobs con PathfindingService.
	Humanoid:MoveTo va en línea recta: contra una roca o un árbol el mob se queda clavado.
	Aquí el camino se calcula de forma asíncrona (no bloquea MobScheduler), se recalcula
	cuando el objetivo se mueve, y si el mob no avanza se descarta el camino y se salta.
]]

local PathfindingService = game:GetService("PathfindingService")

local Pathing = {}

local REPATH_DISTANCE = 6 -- studs que tiene que moverse el objetivo para recalcular
local REPATH_INTERVAL = 1 -- segundos mínimos entre dos cálculos
local WAYPOINT_REACHED = 2.5 -- studs horizontales
local STUCK_WINDOW = 1.5 -- segundos
local STUCK_MIN_PROGRESS = 0.6 -- studs que debe avanzar en cada ventana

local AGENT_PARAMS = {
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = true,
	AgentCanClimb = false,
	WaypointSpacing = 4,
}

export type Walker = {
	humanoid: Humanoid,
	root: BasePart,
	goal: Vector3?,
	waypoints: { PathWaypoint },
	index: number,
	computing: boolean,
	computedAt: number,
	direct: boolean, -- sin camino válido: se intenta ir en línea recta
	checkpoint: Vector3,
	checkpointAt: number,
}

local function flatDistance(a: Vector3, b: Vector3): number
	local d = a - b
	return Vector2.new(d.X, d.Z).Magnitude
end

function Pathing.new(humanoid: Humanoid, root: BasePart): Walker
	return {
		humanoid = humanoid,
		root = root,
		goal = nil,
		waypoints = {},
		index = 1,
		computing = false,
		computedAt = -math.huge,
		direct = false,
		checkpoint = root.Position,
		checkpointAt = 0,
	}
end

function Pathing.reset(walker: Walker)
	walker.waypoints = {}
	walker.index = 1
	walker.direct = false
	walker.computedAt = -math.huge
end

local function compute(walker: Walker, goal: Vector3, now: number)
	walker.computing = true
	walker.computedAt = now
	local start = walker.root.Position
	task.spawn(function()
		local path = PathfindingService:CreatePath(AGENT_PARAMS)
		local ok = pcall(function()
			path:ComputeAsync(start, goal)
		end)
		walker.computing = false
		if ok and path.Status == Enum.PathStatus.Success then
			walker.waypoints = path:GetWaypoints()
			walker.index = 2 -- el primer waypoint es la posición de partida
			walker.direct = false
		else
			walker.waypoints = {}
			walker.index = 1
			walker.direct = true
		end
	end)
end

-- Llamar en cada tick del mob. No cede el hilo: el cálculo del camino va en otro hilo.
function Pathing.follow(walker: Walker, goal: Vector3, now: number)
	local root = walker.root
	local previousGoal = walker.goal
	walker.goal = goal

	-- Vigilancia de atasco: si no avanza en la ventana, se descarta el camino y se salta.
	if now - walker.checkpointAt >= STUCK_WINDOW then
		local progress = flatDistance(root.Position, walker.checkpoint)
		local stillFar = flatDistance(root.Position, goal) > WAYPOINT_REACHED
		walker.checkpoint = root.Position
		walker.checkpointAt = now
		if progress < STUCK_MIN_PROGRESS and stillFar then
			Pathing.reset(walker)
			walker.humanoid.Jump = true
		end
	end

	local goalMoved = previousGoal == nil or flatDistance(previousGoal, goal) > REPATH_DISTANCE
	local pathDone = walker.index > #walker.waypoints
	local stillFar = flatDistance(root.Position, goal) > WAYPOINT_REACHED
	if not walker.computing and now - walker.computedAt >= REPATH_INTERVAL and (goalMoved or (pathDone and stillFar)) then
		compute(walker, goal, now)
	end

	local waypoints = walker.waypoints
	local current = waypoints[walker.index]
	if current ~= nil and flatDistance(root.Position, current.Position) <= WAYPOINT_REACHED then
		walker.index += 1
		current = waypoints[walker.index]
	end

	if current ~= nil then
		if current.Action == Enum.PathWaypointAction.Jump then
			walker.humanoid.Jump = true
		end
		walker.humanoid:MoveTo(current.Position)
	elseif walker.direct and stillFar then
		walker.humanoid:MoveTo(goal)
	end
end

return Pathing

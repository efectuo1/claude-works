--!strict
-- Crea, asigna y destruye instancias privadas de modalidad.
-- Cada instancia vive en un hueco separado del mundo y tiene su propio registro de mobs.
-- No conoce las reglas de cada modalidad: las recibe como "build" (Dungeons, Jefes...).

local InstanceRouter = require(script.Parent.InstanceRouter)

export type ModeHandle = {
	registry: InstanceRouter.TargetLookup, -- registro de mobs propio de esta instancia
	destroy: () -> (),
}

export type Mode = {
	id: string,
	maxPlayers: number,
	-- Construye el mapa en el hueco dado y arranca la modalidad. Devuelve cómo destruirla.
	build: (slot: Vector3, instanceId: string) -> ModeHandle,
}

export type Options = {
	router: InstanceRouter.InstanceRouter,
	modes: { [string]: Mode },
	slotSpacing: number?,      -- distancia entre huecos, en studs
	firstSlot: Vector3?,       -- dónde empieza el primer hueco
	graceSeconds: number?,     -- espera antes de destruir una instancia vacía
	schedule: (seconds: number, fn: () -> ()) -> (),
}

export type InstanceManager = {
	create: (modeId: string) -> (string?, string?),       -- instanceId, error
	join: (userId: number, instanceId: string) -> (boolean, string?),
	leave: (userId: number) -> (),
	count: (instanceId: string) -> number,
}

local DEFAULT_SPACING = 5000
local DEFAULT_GRACE = 10

local InstanceManager = {}

function InstanceManager.new(options: Options): InstanceManager
	local router = options.router
	local spacing = options.slotSpacing or DEFAULT_SPACING
	local firstSlot = options.firstSlot or Vector3.new(0, 0, 10000)
	local grace = options.graceSeconds or DEFAULT_GRACE

	local nextSlot = 0
	local handles: { [string]: ModeHandle } = {}
	local modeOf: { [string]: Mode } = {}
	local members: { [string]: { [number]: boolean } } = {}
	local emptySince: { [string]: number } = {}
	local counter = 0

	local manager = {} :: InstanceManager

	local function destroy(instanceId: string)
		local handle = handles[instanceId]
		if handle then
			handle.destroy()
		end
		handles[instanceId] = nil
		modeOf[instanceId] = nil
		members[instanceId] = nil
		emptySince[instanceId] = nil
		router.destroy(instanceId)
	end

	function manager.create(modeId: string): (string?, string?)
		local mode = options.modes[modeId]
		if mode == nil then
			return nil, "modo_desconocido"
		end
		counter += 1
		local instanceId = `{modeId}-{counter}`
		local slot = firstSlot + Vector3.new(nextSlot * spacing, 0, 0)
		nextSlot += 1
		local ok, handle = pcall(mode.build, slot, instanceId)
		if not ok then
			return nil, "build_fallo"
		end
		handles[instanceId] = handle
		modeOf[instanceId] = mode
		members[instanceId] = {}
		router.create(instanceId, handle.registry)
		return instanceId, nil
	end

	function manager.join(userId: number, instanceId: string): (boolean, string?)
		local mode = modeOf[instanceId]
		if mode == nil then
			return false, "instancia_no_existe"
		end
		local list = members[instanceId]
		if list[userId] then
			return true, nil
		end
		if manager.count(instanceId) >= mode.maxPlayers then
			return false, "instancia_llena"
		end
		list[userId] = true
		emptySince[instanceId] = nil
		router.enter(userId, instanceId)
		return true, nil
	end

	function manager.leave(userId: number)
		local instanceId = router.instanceOf(userId)
		router.leave(userId)
		if instanceId == nil then
			return
		end
		local list = members[instanceId]
		if list then
			list[userId] = nil
		end
		if manager.count(instanceId) == 0 then
			local stamp = os.clock()
			emptySince[instanceId] = stamp
			options.schedule(grace, function()
				-- solo se destruye si nadie ha vuelto en el tiempo de gracia
				if emptySince[instanceId] == stamp and manager.count(instanceId) == 0 then
					destroy(instanceId)
				end
			end)
		end
	end

	function manager.count(instanceId: string): number
		local list = members[instanceId]
		if list == nil then
			return 0
		end
		local n = 0
		for _ in list do
			n += 1
		end
		return n
	end

	return manager
end

return InstanceManager

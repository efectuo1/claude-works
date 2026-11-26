--!strict
-- Relaciona cada jugador con la instancia donde está y devuelve el registro de mobs que le toca.
-- Sin instancia, el jugador usa el mundo general (overworld).
-- Las instancias se crean y destruyen desde InstanceManager (Fase 2, siguiente entrega).

export type TargetLookup = {
	get: (targetId: string) -> any,
	near: (origin: Vector3, radius: number) -> { any },
}

export type InstanceRouter = {
	create: (instanceId: string, registry: TargetLookup) -> (),
	destroy: (instanceId: string) -> (),
	enter: (userId: number, instanceId: string) -> boolean,
	leave: (userId: number) -> (),
	instanceOf: (userId: number) -> string?,
	registryFor: (userId: number) -> TargetLookup,
}

local InstanceRouter = {}

function InstanceRouter.new(overworld: TargetLookup): InstanceRouter
	local registries: { [string]: TargetLookup } = {}
	local playerInstance: { [number]: string } = {}

	local router = {} :: InstanceRouter

	function router.create(instanceId: string, registry: TargetLookup)
		assert(registries[instanceId] == nil, "instancia repetida: " .. instanceId)
		registries[instanceId] = registry
	end

	-- Al destruir una instancia, sus jugadores vuelven al mundo general.
	function router.destroy(instanceId: string)
		registries[instanceId] = nil
		for userId, id in playerInstance do
			if id == instanceId then
				playerInstance[userId] = nil
			end
		end
	end

	function router.enter(userId: number, instanceId: string): boolean
		if registries[instanceId] == nil then
			return false
		end
		playerInstance[userId] = instanceId
		return true
	end

	function router.leave(userId: number)
		playerInstance[userId] = nil
	end

	function router.instanceOf(userId: number): string?
		return playerInstance[userId]
	end

	function router.registryFor(userId: number): TargetLookup
		local id = playerInstance[userId]
		if id == nil then
			return overworld
		end
		return registries[id] or overworld
	end

	return router
end

return InstanceRouter

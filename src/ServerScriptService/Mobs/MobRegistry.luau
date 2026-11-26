--!strict
-- Registro de objetivos atacables. Cada instancia de juego tendra el suyo (Fase 2).
-- La API estatica (MobRegistry.register/get/near) se conserva para el mundo general.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)

export type Registry = {
	register: (targetId: string, target: Types.CombatTarget) -> (),
	unregister: (targetId: string) -> (),
	get: (targetId: string) -> Types.CombatTarget?,
	near: (origin: Vector3, radius: number) -> { Types.CombatTarget },
}

local function newRegistry(): Registry
	local targets: { [string]: Types.CombatTarget } = {}

	local registry = {}

	function registry.register(targetId: string, target: Types.CombatTarget)
		targets[targetId] = target
	end

	function registry.unregister(targetId: string)
		targets[targetId] = nil
	end

	function registry.get(targetId: string): Types.CombatTarget?
		return targets[targetId]
	end

	-- Objetivos vivos dentro de un radio, medido en horizontal (la altura no cuenta).
	function registry.near(origin: Vector3, radius: number): { Types.CombatTarget }
		local found: { Types.CombatTarget } = {}
		for _, target in targets do
			local delta = target.getPosition() - origin
			if Vector3.new(delta.X, 0, delta.Z).Magnitude <= radius then
				table.insert(found, target)
			end
		end
		return found
	end

	return registry :: Registry
end

local MobRegistry = {}
MobRegistry.new = newRegistry

local overworld = newRegistry()
MobRegistry.overworld = overworld
MobRegistry.register = overworld.register
MobRegistry.unregister = overworld.unregister
MobRegistry.get = overworld.get
MobRegistry.near = overworld.near

return MobRegistry

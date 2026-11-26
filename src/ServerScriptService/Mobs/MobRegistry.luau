--!strict
-- Registro en memoria de objetivos atacables activos, indexados por id de instancia.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)

local registry: { [string]: Types.CombatTarget } = {}

local MobRegistry = {}

function MobRegistry.register(targetId: string, target: Types.CombatTarget)
	registry[targetId] = target
end

function MobRegistry.unregister(targetId: string)
	registry[targetId] = nil
end

function MobRegistry.get(targetId: string): Types.CombatTarget?
	return registry[targetId]
end

-- Objetivos vivos dentro de un radio, medido en horizontal (la altura de los mobs no cuenta).
function MobRegistry.near(origin: Vector3, radius: number): { Types.CombatTarget }
	local found: { Types.CombatTarget } = {}
	for _, target in registry do
		local delta = target.getPosition() - origin
		if Vector3.new(delta.X, 0, delta.Z).Magnitude <= radius then
			table.insert(found, target)
		end
	end
	return found
end

return MobRegistry

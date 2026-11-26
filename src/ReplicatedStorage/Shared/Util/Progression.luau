--!strict
--[[
	Curva de nivel. Pura: la usan el servidor (para subir de nivel) y el cliente (para mostrar).
	Cambiar la curva aquí cambia el ritmo de todo el juego. Ajustar con las pruebas de Progression.
]]

local Progression = {}

Progression.MAX_LEVEL = 30

-- XP total necesario para llegar a un nivel: 10 * (nivel - 1)^2.
-- Nivel 10 = 810 XP; nivel 25 = 5760 XP.
function Progression.xpForLevel(level: number): number
	local n = math.max(1, level) - 1
	return 10 * n * n
end

function Progression.levelForXp(xp: number): number
	local level = 1
	while level < Progression.MAX_LEVEL and xp >= Progression.xpForLevel(level + 1) do
		level += 1
	end
	return level
end

return Progression

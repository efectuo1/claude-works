--!strict
--[[
	Reparto de la recompensa según el daño. Quien mata solo tiene el 100 % de probabilidad.
	En grupo, ese 100 % se reparte entre los contribuyentes según su porcentaje de daño.
	Así el total que sale de un mob es el mismo sin importar cuántos participen.
	Lógica pura: el azar entra por parámetro.
]]

local Contribution = {}

export type Shares = { [number]: number }

-- Participación de cada jugador: daño propio / daño total. Suma 1 si hubo daño.
-- Sin daño registrado (datos antiguos), se reparte a partes iguales entre los conocidos.
function Contribution.shares(damageByUser: { [number]: number }?, fallbackUserIds: { number }): Shares
	local damage = damageByUser or {}
	local total = 0
	for _, dealt in damage do
		if dealt > 0 then
			total += dealt
		end
	end

	local result: Shares = {}
	if total > 0 then
		for userId, dealt in damage do
			if dealt > 0 then
				result[userId] = dealt / total
			end
		end
		return result
	end

	if #fallbackUserIds == 0 then
		return result
	end
	local equal = 1 / #fallbackUserIds
	for _, userId in fallbackUserIds do
		result[userId] = equal
	end
	return result
end

-- ¿Este jugador consigue su parte en esta tirada? share 1 siempre, share 0 nunca.
function Contribution.attempt(share: number, random: () -> number): boolean
	if share <= 0 then
		return false
	end
	if share >= 1 then
		return true
	end
	return random() < share
end

return Contribution

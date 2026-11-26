--!strict
--[[
	Qué jugadores siguen presentes en este servidor.
	Un jugador que se está yendo cuenta como ausente aunque Players todavía lo liste:
	así una carga en curso no deja una sesión abierta.
	No conoce Players: recibe la función de búsqueda por parámetro.
]]

export type Presence = {
	isPresent: (userId: number) -> boolean,
	isLeaving: (userId: number) -> boolean,
	markLeaving: (userId: number) -> (),
}

local PlayerPresence = {}

function PlayerPresence.new(getPlayerByUserId: (userId: number) -> Player?): Presence
	local leaving: { [number]: boolean } = {}

	return {
		isPresent = function(userId: number): boolean
			return getPlayerByUserId(userId) ~= nil and not leaving[userId]
		end,
		isLeaving = function(userId: number): boolean
			return leaving[userId] == true
		end,
		markLeaving = function(userId: number)
			leaving[userId] = true
		end,
	}
end

return PlayerPresence

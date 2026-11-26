--!strict
--[[
	Modo de pruebas. Quita niveles y enfriamientos para probar habilidades sin esperas.
	Los datos de nivel (requiredLevel) y de enfriamiento (cooldown) se conservan en Abilities.
	Para volver al ritmo de juego real, poner ambos valores en false.
]]
return table.freeze({
	NO_LEVELS = true,
	NO_COOLDOWNS = true,
	-- Sin mobs o sin objetivo, la habilidad igual se lanza y muestra su efecto (daño 0).
	ALLOW_CAST_WITHOUT_TARGET = true,
})

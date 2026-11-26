# Cambios pendientes (se aplican con Fase 2)

Estos cambios NO están en la Fase 1 a propósito: el juego sigue funcionando sin ellos gracias a la API estática de MobRegistry.

## AbilityService.luau
- Dependencies: reemplazar findTarget y findTargetsNear por:
    registryFor: (userId: number) -> TargetLookup,
- Añadir encima de Dependencies:
    export type TargetLookup = {
        get: (targetId: string) -> Types.CombatTarget?,
        near: (origin: Vector3, radius: number) -> { Types.CombatTarget },
    }
- En cast, tras el bloque de getPosition: local registry = deps.registryFor(userId)
- deps.findTargetsNear(origin, definition.radius) -> registry.near(origin, definition.radius)
- deps.findTarget(targetId) (dos veces) -> registry.get(targetId)

## Bootstrap.server.luau
En AbilityService.new({...}) sustituir findTarget y findTargetsNear por:
    registryFor = function(_userId: number)
        return MobRegistry.overworld
    end,

## Tests/AbilityService.spec.luau
En makeHarness, sustituir findTarget y findTargetsNear por registryFor que devuelve { get = ..., near = ... } sobre la tabla targets.

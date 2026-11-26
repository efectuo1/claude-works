---
tags: [sistema, modalidad, oleadas]
actualizado: 2026-11-26
---
# Modalidad de oleadas (arena)

Especificación: `docs/MODALIDAD_DUNGEON.md` en el proyecto.

## Formato acordado
- 20 oleadas y un jefe final en la 20.
- De 1 a 4 jugadores por partida.
- Mobs normales y zombis. Hay que matarlos con frutas o jutsus.

## Recompensas
- Oro en cada oleada, como cualquier mob (con reparto por daño y pases).
- Gema segura en las oleadas 5, 10 y 15. Gemas al azar en el resto.

## Jefes
- Oleadas 5, 10 y 15: mini jefe con habilidad propia (pendiente de diseñar).
- Oleada 20: jefe final, más fuerte que los mini jefes. El mob no existe todavía en `Mobs.luau`.

## Estado
- **Hecho (parte 17), probado solo en la lógica**: reglas (`WaveRules`) y estado de partida (`WaveSession`), con 9 pruebas.
- **Hecho (parte 17), sin probar en Studio**: `Modes/WaveService`. Portal en la arena con ProximityPrompt, de 1 a 4 jugadores, spawn en anillo, mobs sin respawn, gema segura en 5, 10 y 15, marcador "Oleada N / 20" y avisos de victoria, derrota o salida.
- **Pendiente**: mini jefes con habilidad propia, y el mob del jefe final (la oleada 20 usa el mob fuerte).

## Código
- `Modes/WaveService.luau`: une las reglas con el mundo (portal, mobs, muertes, avisos).
- `Shared/Util/WaveRules.luau`: qué significa cada oleada.
- `Shared/Util/WaveSession.luau`: avance, victoria y derrota.
- `Shared/Util/RoundPlanner.luau`: qué mobs salen en cada ronda (ya existía).

Enlaces: [[Sistemas/Mobs y pathing]], [[Sistemas/Reparto por daño]], [[Sistemas/Mapa y mundo]].


## Jefes

- Oleadas 5, 10, 15: Capitán de Ceniza (`ash_captain`), reutiliza la plantilla del Bruto.
- Oleada 20: Tirano de Brasa (`ember_tyrant`), jefe final, reutiliza la plantilla del Bruto.
- Pendiente: modelos propios y probar en Studio.

- Capitán de Ceniza: embestida y onda de choque cada 7 s (ver docs/CAMBIOS_PARTE17.md). Sin probar.

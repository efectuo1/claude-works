# Modalidad dungeon (especificación, pendiente de implementar)

Estado (parte 17):
- Núcleo puro probado: `Shared/Util/WaveRules` y `WaveSession` (suite `WaveSession.spec`).
- Conectado al mundo, sin probar en Studio: `ServerScriptService/Modes/WaveService`. Portal con ProximityPrompt en la arena, de 1 a 4 jugadores, mobs sin respawn que cuentan para la oleada, XP/oro/objetos por `mobKilled`, gema segura en 5, 10 y 15, marcador "Oleada N / 20" y avisos de victoria, derrota y salida.
- Pendiente: mini jefes con habilidad propia, y el mob del jefe final, que no existe todavía en `Mobs.luau` (la oleada 20 usa el mob fuerte).

## Formato
- 20 oleadas y un jefe final.
- Jugadores por partida: de 1 a 4 (solo, dúo, trío o cuádruple).
- Mobs: zombis y mobs normales; hay que matarlos con frutas o jutsus.

## Recompensas
- Monedas: en cada oleada, de forma habitual.
- Gemas: de vez en cuando; en las oleadas 5, 10 y 15 hay gemas seguras.

## Jefes
- Oleadas 5, 10 y 15: mini jefe con una habilidad propia.
- Oleada 20: jefe final, más fuerte que los mini jefes.
- En cada oleada, mobs y jefes son más numerosos y fuertes que en la anterior.

## Implementado en el núcleo (parte 17)
- `WaveRules.info(n)`: mobs de la oleada (vía `RoundPlanner`), mini jefe y gema segura en 5, 10 y 15, jefe final en la 20.
- `WaveSession`: start, mobsKilled y playersLeft. Devuelve el evento ("oleada_superada", "victoria", "derrota") y no cambia una partida terminada.

## Fuera de alcance por ahora
- Mejoras y tienda de mejoras.
- Torres o trampas colocables (tipo pirata).
- Moneda de mejoras (oro o gemas) y su economía.

## Referencia visual
- Arena circular de madera con agua alrededor, marcador de oleada arriba ("Vague 12 en cours") y paneles de mejoras a los lados.

## Conexión al mundo (parte 17)
- `Modes/WaveService`: portal (ProximityPrompt), entrada/salida, spawn por anillo en la arena, muertes y avance de oleadas.
- `WorldBootstrap.start` devuelve el contexto del controlador y las plantillas para reutilizarlos.
- `WalletService.grantGems` para la gema segura de cada oleada.
- Remoto `WaveFx` (servidor → jugador) para el marcador y los avisos.
- Sin probar en Studio.

---
tags: [sistema, mobs, ia]
---
# Mobs y pathing

## Modelo
- `Mobs.luau`: `ember_wolf` (Lobo de Brasa), `ember_sprite` (Espíritu de Brasa), `ash_brute` (Bruto de Ceniza).
- Plantilla: torso, cabeza y extremidades soldadas. Solo el torso colisiona.
- Etiqueta con el nombre: solo se ve a menos de 90 studs (parte 17).

## Estados
Patrol → Chase → Attack → Return → Dead. Al volver a casa no vuelve a detectar al jugador.

## Movimiento
- `Pathing` con `PathfindingService`. Recalcula si el objetivo se mueve más de 6 studs, como mucho una vez por segundo. Si no avanza 0.6 studs en 1.5 s, descarta el camino y salta.
- Riesgo: `ComputeAsync` tiene coste con muchos mobs.

## Ejecución
- `MobScheduler`: un solo bucle para todos (tick de 0.2 s). `MobSpawner` recrea mobs según `respawnSeconds`.

Enlaces: [[Sistemas/Mapa y mundo]].

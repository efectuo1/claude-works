---
tags: [sistema, mapa]
---
# Mapa y mundo

Generado por código al arrancar (`WorldBuilder`). Si Studio ya trae terreno, no se sobrescribe.

## Disposición (640 studs, de -320 a 320)
- **Oeste (x=-190)**: arena de modalidades. Disco de madera con agua y 12 pilares.
- **Centro (0,0)**: plaza con fuente grande, cabañas y ruleta (`HubBuilder`).
- **Este (x=190)**: tienda con 4 puestos de toldo (`LandmarksBuilder`).
- **Caminos de piedra** (parte 17): franjas de 18 studs con `Cobblestone`, de la plaza a la tienda y a la arena. Tienen prioridad sobre el anillo de arena de la plaza.
- **Campos de mobs**: anillo exterior. Spawns en `MapLayout.SPAWN_POINTS`.

## Piezas
- `MapLayout`: datos puros. Altura, zonas, caminos, spawns, `isClear` y `surfaceAt` (Rock, Sand, Grass, Stone).
- `WorldBuilder`: terreno en vóxeles de 4 studs, luz, decoración (80 rocas, 120 árboles, 16 brasas, 600 flores), plantillas de zombis.

## Riesgos
- Terreno de 640 studs: unas 225 mil celdas. Medir la carga.
- Decoración con semilla fija.
- Pendiente: decidir si el mapa definitivo se hace a mano en Studio.

Enlaces: [[Sistemas/Mobs y pathing]].

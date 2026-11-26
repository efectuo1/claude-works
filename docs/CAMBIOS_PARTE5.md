# Parte 5: mapa más grande, fuente central y tienda única

## Qué cambia
- Mapa de 640 studs (antes 448). Tienda al este (x=190), arena de modalidades al oeste (x=-190).
- Fuente central más grande, con escalón, dos cuencos con agua y chorro.
- Se elimina la segunda tienda que estaba en `HubBuilder`: ahora solo hay una, en el este.
- Cartel de modalidades más ancho y en dos líneas.
- Brillo (bloom) reducido de 0.8 a 0.35.
- Dos campos de mobs nuevos: `Wolf_3` y `Sprite_2` (añadidos a `Zones.luau`).
- Más decoración: 80 rocas, 120 árboles, 16 brasas y 600 flores.

## Cómo probar
1. `rojo build default.project.json -o roblox-anime.rbxlx` y abre el `.rbxlx` nuevo.
2. Play. Debe salir `[MapLayout] 6/6 OK` y `[Tests] todas las suites pasaron`.
3. Mira que el mapa tenga la tienda al este, la arena al oeste y la fuente en el centro.

## Pendiente de verificar en Studio
- Tiempo de carga del terreno de 640 studs (es lo más pesado).
- Que los zombis rodeen árboles y rocas sin quedarse atascados.

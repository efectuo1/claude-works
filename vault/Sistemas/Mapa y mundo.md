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

## Hub: módulos de construcción (mapa y UI v2)
`HubBuilder` solo dispone; las piezas salen de cuatro módulos en `ServerScriptService/World`:
- `HubPrimitives`: partes ancladas, discos, cilindros, estrellas, rombos, carteles con texto y emisores.
- `HubStructures`: `cabin()` construye cabañas de troncos (6 hiladas, esquinas que sobresalen, tejado a 52°, frontones, chimenea con humo, ventanas encendidas, cartel) y el establo rojo de la tienda con el mismo código y otro `Style`.
- `HubLandmarks`: ruleta (bastidor de madera, 8 pétalos, aro con bombillas, flecha) y tres tableros con marco dorado.
- `HubNature`: árboles redondos, pinos de cinco pisos, setos, tocones, setas, hoguera, bancos, vallas, poste de flechas, diana, fardos, barriles, cajas, farolas, huellas, gemas y estrellas.
- `PadBuilder`: aro oscuro, columna de luz translúcida, chispas, luz y rótulo con `MaxDistance` corto.
Contratos que no se deben romper: una única pieza llamada `Ruleta` (Bootstrap le cuelga el prompt de girar) y el `ProximityPrompt` llamado `PromptTienda`.
Las puertas miran a +X local; `HubBuilder` gira cada zona para que mire a la plaza.

## Interfaz (mapa y UI v2)
- El raíl de botones usa `glyph` (emoji sobre insignia redonda) cuando `UiAssets` no tiene imagen; se sustituye solo al rellenar los IDs.
- Tarjeta de monedas más estrecha, moneda con signo y gema en rombo.
- `CombatClient`: estado, misión y habilidades con el aspecto del kit (`kitStyle`).

## Sin verificar en Studio
El hub se ejecutó entero en un entorno simulado (1189 piezas, sin posiciones inválidas, orientaciones comprobadas), pero no se ha visto en Studio. Revisar a ojo: proporciones de cabañas y tejados, ruleta, legibilidad de carteles y emojis de la HUD.

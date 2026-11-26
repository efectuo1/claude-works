# Parte 6: interfaz principal (MainHud)

## Qué cambia
- Nuevo `StarterPlayerScripts/MainHud.client.luau`: monedas arriba a la izquierda, columna de botones, pack de inicio y regalo a la derecha, barra inferior (modalidades, inicio, tienda), barra de nivel con XP y panel reutilizable.
- El servidor escribe el atributo `Xp` (además de `Level`). `ProgressionService` tiene un callback opcional `onXpChanged`, así que los tests existentes no cambian.
- La barra de habilidades sube para dejar sitio a la barra inferior.

## Pendiente
- Monedas (`Gold`) y gemas (`Gems`): no hay sistema de economía todavía. La interfaz ya las lee como atributos; el servidor debe escribirlas cuando exista la economía.
- Todos los paneles marcados "Próximamente" esperan su sistema.

## Cómo probar
1. `rojo build default.project.json -o roblox-anime.rbxlx` y Play.
2. Debe aparecer la interfaz. La barra de nivel muestra NIVEL 1 con su XP.
3. Pulsa los botones: cada uno abre el panel con su texto y se cierra con la X.

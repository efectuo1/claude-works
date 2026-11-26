---
tags: [sistemas, ui, hud]
actualizado: 2026-11-26
---
# Pantallas del HUD

Dos barras de botones: izquierda (TIENDA, RANGO, MEJORAS, ÍNDICE) y derecha (FRUTAS, MODOS, INICIO, AJUSTES).

Cada botón abre una ventana. Las ventanas de texto se crean con `buildNotice` en `FolkHud.client.luau` y comparten el mismo marco de 560 x 300.

Progreso y monedas están en una capa de diseño de 1920 x 1080 que escala con la pantalla.

Código: [[Sistemas/Textos de secciones]] para los textos. [[Sistemas/Componentes FolkStudUI]] para las piezas.

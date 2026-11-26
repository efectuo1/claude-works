---
tags: [referencia, kit]
---
# Skill Folk Stud UI

Skill recibida como `folk-stud-ui.skill`. Contiene:
- `SKILL.md`: guía de estilo y reglas de construcción.
- `references/`: medidas, IDs de assets (studs, rayos, iconos de tienda y rebirth) y flujo de trabajo en Studio.
- `scripts/FolkStudUI.lua`: el kit. `FolkStudClient.lua` y `sample_config.lua`: ejemplos.
- `scripts/icons.py`: busca iconos en el pack FOLK sin descomprimirlo.

## Licencias del pack FOLK
- "Ranks" y "Keyboard Keys": CC0 (RhosGFX).
- "Currency and Items", "Eggs", "Emojis", "Menu and Controls": sin licencia indicada. Revisar antes de publicar.

## Reglas más útiles
- Texto con contorno de 3.7 y `LineJoinMode` Bevel.
- Botones centrados con `UIScale`.
- Un solo tamaño y altura para etiquetas hermanas.
- El rango de cada botón no debe quedar tapado por la X de la cabecera.

Enlaces: [[Sistemas/Interfaz HUD]], [[Sistemas/Iconos y UiAssets]].

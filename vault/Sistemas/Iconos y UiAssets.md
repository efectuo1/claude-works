---
tags: [sistema, ui, arte]
---
# Iconos y UiAssets

- Ocho iconos propios en `assets/iconos/`: moneda, gema, mejoras, índice, frutas, modos, inicio y ajustes. Estilo del kit.
- `Shared/Definitions/UiAssets.luau`: IDs vacíos. Mientras lo estén, el HUD usa la estrella de respaldo.

## Cómo activarlos
1. Subir cada PNG como Decal en Studio (Asset Manager o Import).
2. En la barra de comandos: `game:GetObjects("rbxassetid://<ID_DEL_DECAL>")[1].Texture`
3. Pegar el resultado en `UiAssets.luau`.

## Pack FOLK
El pack oficial tiene más iconos, pero su zip no ha llegado. Si se sube, sustituye a los propios.

# Parte 16: iconos propios para la interfaz

## Qué hay
- `assets/iconos/`: 8 PNG creados para el proyecto (moneda, gema, mejoras, índice, frutas, modos, inicio, ajustes). Estilo del kit: contorno negro, degradado, brillo y sombra.
- `Shared/Definitions/UiAssets.luau`: IDs de imagen de Roblox. Están vacíos, así que la interfaz usa la versión de respaldo hasta que se rellenen.

## Cómo activarlos
1. En Studio, sube cada PNG de `assets/iconos/` como Decal (Asset Manager o Import).
2. En la barra de comandos de Studio: `game:GetObjects("rbxassetid://<ID_DEL_DECAL>")[1].Texture`
3. Pega el resultado en `UiAssets.luau`, en su clave correspondiente.

## Pendiente
- Iconos del pack FOLK, si se suben el zip: sustituyen a los propios.
- Revisar en Studio el tamaño de cada icono dentro de su botón.

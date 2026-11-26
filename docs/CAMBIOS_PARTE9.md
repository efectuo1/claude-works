# Parte 9: suerte de drops según el rango

## Qué cambia
- `DropService.roll(tableId, luck?)`: la suerte cambia el reparto con peso efectivo `peso^(1 - suerte)`. Los objetos raros ganan probabilidad. Sin suerte, el reparto es el original. La suerte se limita a [0, 0.9].
- `KillLootHandler`: pide la suerte del jugador que recibe el loot (opcional en sus dependencias).
- `Bootstrap`: conecta `luckFor` con el rango del perfil (`Rewards.rankOrDefault(rank).luck`).
- Nueva suite `DropLuck.spec` (4 pruebas, con semilla fija). Está registrada en `RunTests`.

## Cómo probar
1. `rojo build default.project.json -o roblox-anime.rbxlx` y Play.
2. Debe salir `[DropLuck] 4/4 OK` sin FAIL.
3. Con un rango alto, los objetos raros deberían salir un poco más a menudo.

## Limitaciones
- Solo cambia el loot del jugador que mata. Los contribuyentes no reciben tirada de objeto, igual que antes.

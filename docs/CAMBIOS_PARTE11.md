# Parte 11: arreglo de los scripts del cliente

## Causa
`default.project.json` apuntaba a `src/StarterPlayerScripts`, pero los scripts están en `src/StarterPlayer/StarterPlayerScripts`. Rojo no encontró la carpeta, dejó `StarterPlayerScripts` vacía y no avisó. Por eso ni la interfaz, ni la barra de habilidades, ni la ruleta llegaban al cliente desde la parte 6.

## Arreglo
Solo se cambia la ruta en `default.project.json`. No se toca ningún script.

## Cómo probar
1. Reconstruir el archivo: `rojo build default.project.json -o roblox-anime.rbxlx`, y abrir ese archivo nuevo.
2. Antes de Play, en el Explorador, `StarterPlayer → StarterPlayerScripts` debe tener `CombatClient`, `MainHud` y `RouletteClient`.
3. Play. En la salida, elige **Client**: debe aparecer `[HUD] iniciando` y `[HUD] lista`.
4. Debe verse la interfaz: monedas, columna de botones, barra inferior y barra de nivel.

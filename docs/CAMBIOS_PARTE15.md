# Parte 15: HUD con el kit Folk Stud UI

## Qué cambia
- Se instala el kit `FolkStudUI` en `src/ReplicatedStorage/FolkStudUI.luau`. Solo se añade al final la tabla `M.helpers` para reutilizar sus piezas.
- Se elimina `MainHud.client.luau` y se añade `FolkHud.client.luau`.
- Raíl izquierdo: TIENDA, RANGO, MEJORAS, ÍNDICE. Raíl derecho: FRUTAS, MODOS, INICIO, AJUSTES.
- RANGO usa la ventana de rebirth del kit, con datos reales de nuestros rangos: nivel, coste, multiplicadores y barra de progreso.
- Progreso (rango, nivel, XP), estadísticas y monedas se construyen con las piezas del kit.
- Las demás secciones muestran un aviso "Próximamente". No hay precios ni objetos falsos.

## Limitaciones
- Los iconos son los placeholders del kit. Los del pack FOLK necesitan subirse a Roblox con Studio, y luego se pasan sus IDs.
- Licencias: "Ranks" y "Keyboard Keys" son CC0. "Currency and Items" y "Menu and Controls" no tienen licencia indicada en el pack. Revisar antes de publicar.
- No probado en Studio. Revisar la salida de cliente: `[FolkHud] iniciando` y `[FolkHud] lista`.

## Cómo probar
1. `rojo build` y Play.
2. Deben verse los dos raíles, el progreso arriba a la izquierda y las monedas arriba a la derecha.
3. Pulsa RANGO: se abre la ventana de rebirth con tus datos. Cierra con CERRAR.
4. Pulsa TIENDA o cualquier otro botón: aparece el aviso "Próximamente".

## Corrección (fallo de arranque)
La salida mostró `attempt to perform arithmetic (div) on number and nil` en `FolkStudUI`, línea 816. Los avisos no definían `NeedW` y `NeedH`, que el kit usa para ajustar la ventana. El error cortaba el script antes de crear el HUD. Corregido en `buildNotice`.

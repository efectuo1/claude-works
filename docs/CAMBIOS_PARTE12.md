# Parte 12: interfaz minimalista y habilidades plegadas

## Interfaz (MainHud v3)
- Izquierda: tarjeta de progreso (rango, nivel y barra de XP), después TIENDA, RANGO, MEJORAS e ÍNDICE, y debajo las estadísticas del rango (suerte, oro y gemas).
- Derecha: tarjeta de monedas (oro y gemas), y debajo FRUTAS / JUTSUS, MODALIDADES, INICIO y AJUSTES.
- Eliminados: logo grande, PACK DE INICIO y REGALO.
- Un solo panel abierto a la vez. Se cierra con la X, con Esc, o pulsando el mismo botón otra vez.
- Sin animaciones de escala al pulsar (causa del botón "pegado").

## Habilidades (CombatClient)
- Plegadas por defecto. Botón discreto "HABILIDADES [+]" abajo al centro.
- Las teclas 1-4 siguen funcionando.
- El texto de objetivo y la misión bajan para no chocar con la barra de Roblox.

## Cómo probar
1. Reconstruir con `rojo build` y Play.
2. La izquierda debe mostrar la barra de XP y los cuatro botones.
3. Pulsa cada botón: se abre un panel, y la X o Esc lo cierran.
4. Pulsa HABILIDADES [+] para desplegarlas y [-] para plegarlas.

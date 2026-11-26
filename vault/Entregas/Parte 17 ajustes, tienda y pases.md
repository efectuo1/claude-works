---
tags: [entrega, ui, tienda, mapa, economia]
fecha: 2026-11-26
---
# Parte 17: ajustes de interfaz, mapa, tienda y pases

## Interfaz y mapa (captura de la parte 16)
- Tarjeta NOVATO bajada de y=70 a y=136: ya no tapa la barra de Roblox.
- Tarjeta de monedas bajada de y=190 a y=236: hueco con el botón de misión.
- Etiquetas de mobs con `MaxDistance = 90`: dejaban de encimarse.
- Caminos de piedra: plaza-tienda y plaza-arena con `Cobblestone`. Tienen prioridad sobre el anillo de arena.

## Oro repartido por daño
- El oro del mob se tira una vez por muerte (`Rewards.rollMobPool`).
- Cada contribuyente recibe su parte según su daño, multiplicada por su rango.
- Las gemas siguen tirándose por persona, con probabilidad escalada por la participación.
- Cambia la regla de la parte 7-10 ("cada contribuyente tira su propia recompensa"). Ver [[Referencias/Decisiones de diseño]].

## Tienda
- Ventana [[Sistemas/Tienda y pases]]: cambio oro↔gemas (200 oro = 1 gema), pases de Robux, códigos "Próximamente".
- Remoto `ExchangeCurrency`, limitado a 5 peticiones por segundo.

## Pases de Robux
- Tres pases propuestos (precios provisionales): Oro x2, Suerte VIP y Gemas x2.
- Propiedad en `GamePassService`: se pregunta a Roblox al entrar y tras cada compra.
- Atributos `Pase_<id>` en el jugador para la interfaz.

## Sin probar
- Nada de esta entrega se ha ejecutado en Studio todavía. Ver [[Estado/Pruebas]].

Enlaces: [[Sistemas/Mapa y mundo]], [[Sistemas/Interfaz HUD]], [[Sistemas/Economía]], [[Sistemas/Tienda y pases]].

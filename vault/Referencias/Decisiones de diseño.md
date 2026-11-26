---
tags: [referencia, decisiones]
actualizado: 2026-11-26
---
# Decisiones de diseño

## Servidor autoritativo
Lo que da valor (daño, oro, gemas, rangos, misiones, cambios, pases) lo decide el servidor.

## Datos separados de la lógica
Cifras en `Definitions` (incluidos precios y pases). Reglas en `Util`. Así se cambian números sin tocar código.

## Mapa generado por código (provisional)
Reproducible y versionable, pero pesado al arrancar. Abierto: ¿mapa definitivo a mano en Studio?

## Gemas escasas, oro común
Acordado con el usuario.

## Oro repartido por daño (parte 17)
Decidido por el usuario. Reemplaza la regla anterior "cada contribuyente tira su propia recompensa de oro". Una tirada por muerte, reparto por daño, multiplicado por el rango de cada jugador.

## Rangos decididos por el jugador
Subir no es automático: el jugador paga cuando quiere.

## Migraciones, no reescrituras
El esquema del perfil cambia por versiones. Nunca se edita una migración publicada.

## Adoptar el kit Folk Stud UI
Ajustar a mano no llegaba al estilo pedido. Se reutiliza el kit en vez de crear piezas nuevas.

## Iconos propios antes que placeholders
Mejor un icono sencillo en el estilo correcto que una estrella de respaldo para siempre.

## Cambio oro↔gemas a 200 (parte 17)
Decidido por el usuario, sin comisión. Coherente con los rangos.

## Pases que dan ventaja, no contenido bloqueado (parte 17)
Oro x2, suerte y gemas x2. Ningún pase desbloquea zonas ni rangos. "Mochila extra" se quitó porque el juego no tiene límite de espacios.

## Precios provisionales (parte 17)
Claude decide los precios de los pases de forma provisional porque el usuario trabaja desde el móvil. El usuario los ajusta en `Shop.luau` desde PC.

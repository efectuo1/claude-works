---
tags: [sistema, economia]
---
# Economía: oro, gemas y cambio

Cifras en `Economy.luau`. Diseño acordado con el usuario, salvo lo marcado como provisional.

## Oro (común)
- Sale de mobs, misiones, mazmorras y jefes. Lobo 8-14, espíritu 5-9, bruto 25-40, jefe 200-400.
- **Parte 17**: el oro de cada mob se tira una vez y se reparte según el daño. Cada parte se multiplica por el rango de su jugador y por su pase Oro x2, si lo tiene.
- Uso previsto: rangos y mejoras de frutas y jutsus (sin diseñar).

## Gemas (escasas)
- Espíritu 1 % y lobo 2 % por persona que contribuye. Élite 10 %. Jefes: al menos 1.
- Misiones: `first_hunt` da 150 oro y 1 gema.
- Pase Gemas x2 duplica la probabilidad.

## Cambio oro↔gemas (parte 17)
- `Economy.EXCHANGE.goldPerGem = 200`, en las dos direcciones, sin comisión.
- Coherente con los rangos: 2000 oro = 10 gemas, 8000 oro = 40 gemas.
- Validación pura en `Rewards.exchange`; aplicación en `WalletService.exchange`.

## Código
- `Rewards.luau` (reglas puras), `WalletService.luau` (escribe en el perfil), `Shared/Util/Perks` (pases).
- Enganches: `mobKilled` (oro repartido y gemas por persona) y `questCompleted` en `Bootstrap`.

Enlaces: [[Sistemas/Tienda y pases]], [[Sistemas/Reparto por daño]], [[Sistemas/Rangos]].

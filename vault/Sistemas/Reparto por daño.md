---
tags: [sistema, reparto]
---
# Reparto por daño

- Quien mata solo: 100 % de probabilidad de objeto y de gema, y todo el oro del mob.
- En grupo: el 100 % de objetos se reparte según el porcentaje de daño. El total que sale del mob es el mismo.
- **Oro (parte 17)**: se reparte también. Una tirada por muerte; cada parte = oro × participación × mult. de rango × mult. de pase.
- **Gemas**: se tiran por persona, con probabilidad × participación.
- Cuenta el daño que quita vida real. El exceso del golpe final no suma.

## Código
- `Mob` registra el daño por jugador (`damageByUserId`).
- `Contribution` (puro): calcula participaciones.
- `KillLootHandler` reparte objetos. `Bootstrap` reparte oro y gemas con `Rewards.rollMobPool` y `WalletService.rewardMob`.

Enlaces: [[Sistemas/Economía]], [[Referencias/Decisiones de diseño]].

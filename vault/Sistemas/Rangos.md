---
tags: [sistema, rangos]
---
# Rangos

Al llegar a un nivel, el jugador puede subir pagando. Es decisión suya.

| Rango | Nivel | Coste | Oro x | Gemas x | Suerte |
|---|---|---|---|---|---|
| Novato | 1 | 0 | 1 | 1 | 0 % |
| Aprendiz | 10 | 500 oro | 1.15 | 1.1 | +5 % |
| Guerrero | 20 | 2000 oro, 10 gemas | 1.35 | 1.25 | +10 % |
| Maestro | 35 | 8000 oro, 40 gemas | 1.6 | 1.5 | +18 % |
| Leyenda | 50 | 25000 oro, 120 gemas | 2 | 2 | +30 % |

- `Rewards.canRankUp` devuelve el motivo: `nivel_insuficiente`, `oro_insuficiente`, `gemas_insuficientes`, `rango_maximo`.
- `WalletService.rankUp` valida y descuenta a la vez.
- Ventana de rangos: la del kit, con datos reales. Pendiente de confirmar.

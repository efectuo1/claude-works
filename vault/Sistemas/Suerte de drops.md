---
tags: [sistema, drops]
---
# Suerte de drops

- Cada rango da suerte: 0 % a +30 %.
- `DropService.roll(tableId, luck)` aplica el peso efectivo `peso^(1 - suerte)`. Los objetos raros ganan probabilidad.
- Sin suerte, el reparto es el original. Independiente del orden de las entradas. La suerte se limita a [0, 0.9].

---
tags: [sistema, tienda, monetizacion]
---
# Tienda y pases

## Ventana FolkTienda
- **Cambio oro↔gemas**: botones x1, x10 y MÁX. La tasa está en `Economy.EXCHANGE.goldPerGem = 200`.
- **Pases de Robux**: lista desde `Shared/Definitions/Shop.luau`. Con `gamePassId = 0` se muestran sin venderse.
- **Códigos**: "Próximamente". Requiere migración v5 del perfil para guardar los ya usados.

## Pases propuestos (provisionales)
| Pase | Efecto | Precio R$ | id |
|---|---|---|---|
| Oro x2 | Doble oro de los mobs | 399 | `doble_oro` |
| Suerte VIP | +10 % de suerte en objetos | 299 | `suerte_vip` |
| Gemas x2 | Doble probabilidad de gemas | 499 | `gemas_x2` |

Se quitó "Mochila extra": el inventario no tiene límite de espacios, solo `maxStack` por objeto.

## Detalles de interfaz
- Filas de pase: muestran ACTIVO si el jugador ya lo tiene (atributo `Pase_<id>`).
- Oro x2 lleva el destello dorado del kit (`Glint`).
- Cambio correcto: aviso "¡Cambio hecho!" sobre la tarjeta de monedas.

## Código
- `ServerScriptService/Monetization/GamePassService`: propiedad (inyectada, probable con `UserOwnsGamePassAsync`).
- `Shared/Util/Perks`: convierte pases en multiplicadores (puro). La suerte tiene tope 0.9.
- Efectos aplicados: `Rewards.rollMob` (oro y gemas) y `Bootstrap` (suerte de drops).
- Compra: `MarketplaceService:PromptGamePassPurchase` desde el cliente; `PromptGamePassPurchaseFinished` refresca en el servidor.

## Pendiente
- Crear los pases en el Creator Hub y pegar los IDs en `gamePassId`.
- Oro y gemas por Robux: más adelante.
- Códigos: más adelante.
- Los precios los decide Claude de forma provisional; el usuario los ajusta en `Shop.luau` desde PC.

Enlaces: [[Sistemas/Economía]], [[Entregas/Parte 17 ajustes, tienda y pases]].

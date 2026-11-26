# Parte 17: ajustes de interfaz, mapa, reparto de oro y tienda

## Qué cambia
- **Tarjeta de progreso** (NOVATO): bajada de y=70 a y=136. Ya no tapa la barra de Roblox ni la franja de estadísticas.
- **Tarjeta de monedas**: bajada de y=190 a y=236, con unos 54 px de hueco bajo el botón de misión. Los avisos "+oro" y "+gemas" suben con ella.
- **Etiquetas de mobs**: `MaxDistance = 90` studs. Antes se veían a cualquier distancia y se encimaban.
- **Caminos de piedra**: los caminos plaza-tienda y plaza-arena usan `Cobblestone` (superficie `Stone`). Tienen prioridad sobre el anillo de arena de la plaza, para que no se corten.
- **MapLayout**: comentario corregido. El mapa va de -320 a 320 (640 studs), no de -224 a 224.
- **Oro repartido por daño** (decisión tomada): el oro de cada mob se tira una vez por muerte (`Rewards.rollMobPool`) y cada contribuyente recibe su parte según el daño. Su parte se multiplica por su rango. Las gemas siguen tirándose por persona, con su probabilidad escalada por la participación. Esto cambia la decisión anterior "cada contribuyente tira su propia recompensa".
- **Pases de Robux, con efecto real** (`Shared/Util/Perks`, `ServerScriptService/Monetization/GamePassService`):
  - Oro x2 (399 R$), Suerte VIP (299 R$), Gemas x2 (499 R$). Precios y efectos provisionales en `Shop.luau`.
  - Propiedad consultada con `UserOwnsGamePassAsync` al entrar y tras cada compra. Sin ID (0) no se pregunta.
  - Atributos `Pase_<id>` en el jugador. La tienda avisa si ya lo tienes.
  - Las filas muestran ACTIVO en lugar del precio. Oro x2 lleva el destello dorado del kit.
- Tras cada cambio correcto aparece "¡Cambio hecho!" sobre la tarjeta de monedas.
  - "Mochila extra" se quitó: el juego no tiene límite de espacios.
- **Tienda** (ventana FolkTienda, reemplaza el "Próximamente"):
  - Cambio oro → gemas y gemas → oro a 200 oro por gema (`Economy.EXCHANGE.goldPerGem`), con botones x1, x10 y MÁX.
  - El servidor valida el cambio (`Rewards.exchange`, puro), aplica el saldo en `WalletService.exchange` y limita a 5 peticiones por segundo (`ExchangeCurrency`).
  - Códigos: sección "Próximamente".

## Cómo probar
- Play en Studio a 1920×1080 y en una ventana más estrecha: la tarjeta NOVATO no tapa la barra de Roblox y la de monedas no toca el botón de misión.
- Recoger oro y gemas: los avisos flotantes aparecen encima de la tarjeta de monedas.
- Acercarse a un mob: aparece su nombre. Desde más de 90 studs, no.
- Caminar de la plaza a la tienda y a la arena: el suelo es de piedra.
- Matar un mob en grupo: el oro que ves sale de un solo reparto, y la suma de las partes coincide con el oro del mob (salvo redondeo).
- Tienda: con 500 oro, x1 da 1 gema y quedan 300. MÁX con gemas vende todas. Con poco oro, el aviso lo dice.
- Suites `MapLayout`, `Rewards` y `GamePassService` (nueva, registrada en `RunTests`): reparto de oro, cambio, pases y propiedad.

## Pendiente
- **Sin probar en Studio**: estos cambios no se han ejecutado (no hay Luau en el entorno de trabajo). Ejecuta Play y mira la salida de las suites.
- **Pases de Robux**: crea los tres pases en el Creator Hub y pega cada ID en `gamePassId` de `Shop.luau`. Hasta entonces no se venden. Los efectos se aplican solo a quien tiene el pase.
- **Oro y gemas por Robux**: pendiente, más adelante.
- **Precios y tasas**: provisionales, decididos por Claude. Ajustables en `Shop.luau` y `Economy.luau`.
- **Códigos de regalo**: pendiente, más adelante. Al canjearlos habrá que guardar los ya usados (migración v5 del perfil).
- Iconos propios: faltan los IDs de imagen en `UiAssets.luau`.
- Guardado: activar los servicios de API en Studio.
- `assets/iconos/` no va en este zip: usa tu copia para los PNG.

## Modalidad de oleadas (núcleo)
- `Shared/Util/WaveRules` y `Shared/Util/WaveSession`: reglas y estado de la partida, puros y con pruebas (`WaveSession.spec`).
- La arena ya no dice "próximamente": cartel "Oleadas (en preparación)" y ventana de Modalidades con la descripción.
- Sin conectar al mundo todavía: no hay spawn de oleadas en la arena. Ver `docs/MODALIDAD_DUNGEON.md`.

## Correcciones
- `Bootstrap`: si un jugador se va mientras se consultan sus pases, no se guardan.

## Jefes de oleadas (añadido)

- `ash_captain` (Capitán de Ceniza): jefe de las oleadas 5, 10 y 15. 900 de vida, 150 XP, oro 60–90.
- `ember_tyrant` (Tirano de Brasa): jefe final de la oleada 20. 3000 de vida, 600 XP, oro 150–220.
- Ambos reutilizan la plantilla `ash_brute` mediante el campo `templateId` (nuevo en `MobDef`). Cuando tengan modelo propio en Studio, basta con cambiar ese campo y crear la plantilla con su id.
- `WaveRules.info` sustituye el mob fuerte de la ronda por el jefe en las oleadas de jefe. `RoundPlanner.strongMob()` expone ese mob.
- La etiqueta de oleada muestra "JEFE" cuando la oleada trae jefe.
- Tests nuevos en `WaveSession.spec`: los jefes sustituyen al mob fuerte en la 5 y la 20 y no aparecen en la 3.

Pendiente de probar en Studio: que el jefe aparece con su plantilla, su barra de vida y su recompensa.

## Animaciones y UI (esta vuelta)

- Textos flotantes (oro, gemas, cambios) entran con rebote de escala (`UIScale`, Back) antes de subir y desvanecerse.
- Efectos de combate (esferas y anillos de habilidad) usan Quint Out: crecen rápido y frenan al final.
- Desaparición de mobs con Quad In: se mantienen un momento y luego se desvanecen.
- No se ha usado Blender: no está instalado en el entorno y el acceso a GitHub falló. Las animaciones de personaje (keyframes, IDs de animación) siguen pendientes; el flujo de exportación está en la skill blender-animation-export.
- Sin probar en Studio.

## Habilidades del Capitán de Ceniza (añadido)

- Campos nuevos en `MobDef`: `abilities` (lista cíclica) y `abilityCooldown`.
- `ash_captain` usa `{ "charge", "shockwave" }` cada 7 segundos.
- Embestida ("charge"): desde 12 studs o más, el mob corre hacia el objetivo a velocidad 42 durante 1 segundo. Si acierta, hace 1.5 veces su daño y se queda aturdido 1.2 segundos.
- Onda de choque ("shockwave"): cuando está pegado al objetivo, golpea con 1.3 veces su daño y hace una pausa de 0.6 segundos. Limitación: por ahora solo golpea al jugador más cercano, porque el controlador solo recibe un objetivo. Si se quiere área real, hace falta una dependencia que devuelva todos los jugadores en radio.
- `ContentValidator` rechaza habilidades desconocidas y habilidades sin `abilityCooldown` positivo. Tests añadidos.
- Sin probar en Studio. La velocidad de embestida y las pausas son valores de partida para ajustar al verlas.

## Recompensa de victoria en oleadas (añadido)

- Al superar la oleada 20 (victoria), cada jugador que siga dentro recibe la recompensa de jefe: `Rewards.rollBoss` con su rango (oro en rango y gemas garantizadas).
- Nuevo `WalletService.rewardBoss(userId)`, conectado en Bootstrap como `grantBoss` a WaveService.
- Limitación: la recompensa de jefe no aplica los pases de oro o gemas (`rollBoss` no recibe perks). Ajustar si se quiere.
- Sin probar en Studio.

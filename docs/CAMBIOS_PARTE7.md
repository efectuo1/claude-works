# Parte 7: economía (oro, gemas y rangos) e interfaz v2

## Diseño de la economía
- **Oro** (común): misiones, mobs, mazmorras y jefes. Cuanto más difícil la fuente, más oro. Sirve para subir de rango y, más adelante, para mejorar frutas y jutsus.
- **Gemas** (escasas): los mobs normales tienen 1-2 % por persona que contribuye, los élite 10 %, los jefes siempre al menos 1, y las misiones solo algunas.
- **Rangos**: Novato, Aprendiz, Guerrero, Maestro y Leyenda. Subir exige nivel mínimo y pagar oro (y gemas desde Guerrero). Cada rango multiplica oro, gemas y suerte de drop (la suerte aún no la usa el DropService).

## Cambios técnicos
- `Shared/Definitions/Economy.luau`: cifras de oro y gemas por fuente (datos).
- `Shared/Definitions/Ranks.luau`: rangos en orden, con nivel, coste y multiplicadores.
- `Shared/Util/Rewards.luau`: reglas puras (tiradas, misiones, jefes, validación de rango). El azar entra por parámetro.
- `ServerScriptService/Economy/WalletService.luau`: monedero. Escribe en el perfil cargado y el autoguardado lo persiste.
- Perfil a **esquema v4**: gold, gems y rank, con migración desde v3 (empieza en 0 y novato).
- `Bootstrap`: enganche a `mobKilled` (cada contribuyente tira su recompensa), a `questCompleted`, y remotos `WalletFx` y `RankUp`.
- Atributos del jugador: `Gold`, `Gems`, `Rank`, `Xp`, `Level`.
- Interfaz `MainHud` v2: logo con brillo, monedas con avisos flotantes "+N", botones con muelle al pulsar, barra de nivel con rango, aviso rojo en RANGO cuando se puede subir, panel de rangos con botón de subida.

## Pendiente
- Mazmorras y jefes: `Rewards.rollBoss` y las cifras de `Economy.BOSS` ya están listos; falta el sistema de mazmorras que los llame.
- El `DropService` debe leer `Ranks.luck` para la suerte de frutas y jutsus.
- Ajustar cifras en la pasada de balance.

## Cómo probar
1. `rojo build default.project.json -o roblox-anime.rbxlx` y Play.
2. Debe salir `[Rewards] 10/10 OK` sin FAIL.
3. Mata mobs: aparece "+N" dorado y, a veces, "+1" verde (gemas).
4. Con nivel y oro suficientes, el botón RANGO muestra un punto rojo. Pulsa SUBIR DE RANGO en el panel.

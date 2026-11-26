---
tags: [estado, bugs]
actualizado: 2026-11-26
---
# Bugs y riesgos

## Corregidos
- **Autoguardado rechazado (`profile_corrupt`)**: `snapshotFor` no incluía oro, gemas ni rango. Parte 8.
- **Scripts del cliente no llegaban a Studio**: ruta mal escrita en `default.project.json`. Parte 11.
- **HUD del kit no arrancaba**: los avisos no tenían `NeedW` y `NeedH`. Parte 15.
- **HUD se detenía si faltaba `UiAssets`**. Parte 16.
- **Iconos que tapaban letras y botones planos**. Parte 14.
- **Tarjeta de progreso sobre la barra de Roblox**. Parte 17 (sin probar).
- **Tarjeta de monedas pegada al botón de misión**. Parte 17 (sin probar).
- **Etiquetas de mobs encimadas**. Parte 17 (sin probar).

## Abiertos
- **Mob del jefe final no existe**: la oleada 20 se marca como final, pero `Mobs.luau` no tiene su definición.
- **Datos sin guardar en Studio**: activar los servicios de API en la configuración del juego.
- **Mobs atascados**: pedir el log `[World]` y la posición.
- **Carga del terreno de 640 studs**: si tarda demasiado, bajar `HALF_SIZE` en `MapLayout`.
- **Ruleta**: no funciona. Premios en "entrega pendiente".
- **Iconos de respaldo**: estrellas hasta subir los PNG.
- **Documento faltante**: `docs/ARQUITECTURA.md` (§6.1) no está en las subidas.

## Riesgos nuevos (parte 17)
- **Modalidad de oleadas sin probar en Studio**: el portal, el spawn en anillo y el cierre de partida no se han ejecutado. Riesgo: una oleada que no se cierra si un mob no muere.
- **Propiedad de pases sin servicios de API**: `UserOwnsGamePassAsync` falla y el jugador cuenta como "no lo tiene". Esperado en Studio sin API, pero hay que probarlo con el juego publicado.
- **Reparto de oro con pases**: el oro total de un mob ya no es fijo si hay pases o rangos distintos. Es intencionado, pero conviene revisar el balance.
- **Caminos de piedra**: `Cobblestone` debe existir como material de terreno en la versión de Studio que use el usuario.

- Riesgo: los jefes de oleada reutilizan la plantilla del Bruto de Ceniza hasta tener modelo propio.
- Riesgo: el token de GitHub falló; no se pudo leer ni subir al repositorio desde esta sesión.

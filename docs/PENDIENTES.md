# Pendientes y revisiones - claude-works

Estado de la entrega acumulada. Todo lo marcado como "revisar en Studio" no se ha podido probar fuera de Roblox Studio.

## Hecho en esta entrega
- Pociones de XP x2 (10 y 15 min): objetos del inventario. Usar una gasta una de la mochila (USAR). Compra con gemas en la pestaña POCIONES de la tienda.
- Temporizador de pociones (PotionTimer): del mismo tipo se suman; de otro tipo, espera en cola. Suite PotionTimer.spec.
- Mochila: ventana del kit con el inventario real, reconstruida al cambiar.
- Indicador "XP x2 · m:ss" en pantalla mientras dura la poción.
- Teletransporte a oleadas y jefes: avisa en la consola si el personaje no está listo, en vez de fallar en silencio.
- MobRegistry como fábrica (MobRegistry.new) con API estática conservada.
- AbilityService usa registryFor(userId) en lugar de registros globales.
- InstanceRouter: enruta cada jugador a su partida. Tiene suite de pruebas (InstanceRouter.spec).
- InstanceManager: crea y destruye instancias con hueco propio (no conectado todavía).
- WaveService: cada partida tiene registro propio, dificultad elegible y +5 % de vida por ronda (provisional).
- Oleadas: tres portales (Normal, Difícil, Pesadilla) delante de la arena y portal de salida al lado.
- Modo Jefes (JefesService): elegir jefe y dificultad, requisito de nivel, hasta 4 jugadores, recompensa al morir el jefe.
- Modo Jefes: seis portales (jefe x dificultad) y portal de salida que devuelve al jugador a la entrada.
- Cabañas del hub (HubBuilder): Oleadas y Jefes tienen pads brillantes que llevan al lobby de su modalidad; las otras dos dicen "Próximamente".
- Modalidades (ModeLayout + ModeArenaBuilder + PadBuilder): arena con plataforma central, aparición en plataformas, puentes con barandilla y agua; sala de jefes con lobby, puente y arena. Caer vuelve a la plataforma central. Probar en Studio.
- Ventana de Modalidades: lista de jefes con su nivel mínimo y si está bloqueado (remoto BossList).
- Fin de jefe: el HUD muestra su propio mensaje, no el de oleadas. Los errores de entrada a jefes tienen su texto.
- Ruleta: el oro y las gemas se entregan de verdad. Frutas y jutsus no tienen catálogo: avisan y no gastan el giro.
- Tienda con pestañas TODO, CAMBIO, PASES y FRUTAS (FolkHud.client.luau).
- Jefe final de oleadas (ember_tyrant) y mini jefes (ash_captain) existen en Mobs.luau.

## Revisar en Studio (no probado)
- [ ] Tienda: abre, las cuatro pestañas cambian y la pestaña activa se marca con > <.
- [ ] Portales de oleadas: no quedan dentro del suelo ni fuera del mapa. Están en arenaCenter + (-8/0/8, -2, 26).
- [ ] Salida de oleadas: el portal está en arenaCenter + (0, -2, 34). Comprobar que alcanza desde la arena.
- [ ] Sala de jefes: Vector3(0, 6, 180) para portales, Vector3(0, 6, 220) para el jefe, Vector3(0, 6, 166) para la salida. Cambiar en Bootstrap si cae mal.
- [ ] Salida de consola: sin errores de tipos en WaveService, JefesService, Bootstrap y FolkHud.
- [ ] Tests: "[Tests] todas las suites pasaron" sigue apareciendo, con InstanceRouter incluido.
- [ ] Un jugador entra a oleadas, sale por el portal y vuelve a la plaza.
- [ ] Un jugador entra a jefes, sale por el portal y vuelve a la entrada.
- [ ] Dos jugadores entran al mismo jefe: el segundo se une sin crear otra partida.
- [ ] Ruleta: el oro y las gemas suben el marcador; frutas y jutsus muestran el aviso.
- [ ] Ventana de Modalidades: se rellena al abrirla y cambia al subir de nivel.
- [ ] Asset "203785492 no coincide con el tipo": no viene de este repositorio. Buscarlo en el kit o en los decals de Studio.

## Pendiente de diseño (acordado, sin construir)
- [ ] Multiplicadores de XP que faltan en la fórmula: pase y dificultad. Solo se aplica el de pociones.
- [ ] Pociones de daño y suerte (el doc las deja para más adelante).
- [ ] Precio en gemas de las pociones (ahora provisional: 40 y 55).
- [ ] Nombres definitivos de los jefes (ahora se ven los ids internos en los portales).
- [ ] Niveles mínimos de jefes (ahora provisionales: 5 y 10).
- [ ] Jefes de One Piece y Naruto, con sus modelos.
- [ ] Habilidades del jefe final (ember_tyrant no tiene todavía habilidades especiales).
- [ ] Multiplicadores de dificultad y de vida por ronda (ahora provisionales).
- [ ] Frutas y jutsus: catálogo y entrega. Mientras tanto, los premios de la ruleta de esos tipos no se entregan.
- [ ] Mapa de Dungeons: 5 plataformas con puentes (no hecho).
- [ ] Mapa libre con secretos y jefes (último, en espera).
- [ ] Mejoras, Ajustes, códigos y pases de Robux (IDs de pase todavía en 0).

## Pendiente técnico
- [ ] Las pociones activas no se guardan entre sesiones (estado en memoria).
- [ ] Revisar en Studio: el portal de salida de jefes y las posiciones de los portales de la arena.
- [ ] InstanceManager no está conectado: las modalidades usan el enrutador directamente. Conectarlo cuando haya más de una instancia a la vez.
- [ ] Tests para JefesService. Necesitan mocks de Mob/MobController; por ahora no hay suite.
- [ ] Los tipos MobRegistry.Registry e InstanceRouter.InstanceRouter se importan desde otros módulos: si Studio marca error, revisar primero aquí.
- [ ] Ambas modalidades comparten el canal WaveFx. El cliente distingue jefe de oleadas por el campo "boss" del mensaje "end".

## Modalidades y UI (sin probar en Studio todavía)
- Hecho: ventana de modalidades con tarjetas y botón "IR A LA ENTRADA" (GoToMode; no deja cambiar de modalidad dentro de una partida).
- Hecho: marcador de oleadas "Oleada N / 20 · Quedan X".
- Hecho: sala de jefes con recuperación de caídas; XP escalada por dificultad (Normal x1, Difícil x1.5, Pesadilla x2, provisional).
- Hecho: pociones guardadas en el perfil (esquema v5, segundos restantes).
- Hecho: inventario por categorías (pociones, llaves, frutas, accesorios, materiales) con emblemas propios; oro y gemas aparte.
- Hecho: ventana PREMIOS con regalo diario (racha de 7 días, esquema v6) y premios por tiempo seguido (15/30/60/90/120 min, por sesión).
- Pendiente: uso real de llaves, frutas y accesorios (sin efecto todavía); equipar accesorios; iconos reales (rellenar UiAssets en Studio), pulido del resto de ventanas, frutas y jutsus, multiplicadores de pases de XP (los pases actuales solo afectan oro y gemas), pathfinding de mobs (la arena usa puentes con barandilla).

# Pendientes y revisiones - claude-works

Estado de la entrega acumulada. Todo lo marcado como "revisar en Studio" no se ha podido probar fuera de Roblox Studio.

## Hecho en esta entrega
- MobRegistry como fábrica (MobRegistry.new) con API estática conservada.
- AbilityService usa registryFor(userId) en lugar de registros globales.
- InstanceRouter: enruta cada jugador a su partida.
- InstanceManager: crea y destruye instancias con hueco propio (no conectado todavía).
- WaveService: cada partida tiene registro propio, dificultad elegible y +5 % de vida por ronda (provisional).
- Oleadas: tres portales (Normal, Difícil, Pesadilla) delante de la arena.
- Modo Jefes (JefesService): elegir jefe y dificultad, requisito de nivel, hasta 4 jugadores, recompensa al morir el jefe.
- Modo Jefes conectado en Bootstrap, con seis portales (jefe x dificultad).
- Tienda con pestañas TODO, CAMBIO, PASES y FRUTAS (FolkHud.client.luau).

## Revisar en Studio (no probado)
- [ ] Tienda: abre, las cuatro pestañas cambian y la pestaña activa se marca con > <.
- [ ] Portales de oleadas: no quedan dentro del suelo ni fuera del mapa. Están en arenaCenter + (-8/0/8, -2, 26).
- [ ] Sala de jefes: Vector3(0, 6, 180) para portales y Vector3(0, 6, 220) para el jefe. Cambiar en Bootstrap si cae mal.
- [ ] Salida de la consola: sin errores de tipos en WaveService, JefesService y AbilityService.
- [ ] Tests: "[Tests] todas las suites pasaron" sigue apareciendo.
- [ ] Un jugador entra a oleadas y sale: su registro se limpia y vuelve al mundo.
- [ ] Dos jugadores entran al mismo jefe: el segundo se une sin crear otra partida.

## Pendiente de diseño (acordado, sin construir)
- [ ] Nombres definitivos de los jefes (ahora se ven los ids internos en los portales).
- [ ] Niveles mínimos de jefes (ahora provisionales: 5 y 10).
- [ ] Jefes de One Piece y Naruto, con sus modelos.
- [ ] Multiplicadores de dificultad y de vida por ronda (ahora provisionales).
- [ ] Casas del hub que abren cada modalidad (no hecho).
- [ ] Ventana de modos que muestra requisitos y bloqueos (no hecho).
- [ ] Mapa de Dungeons: 5 plataformas con puentes (no hecho).
- [ ] Mapa libre con secretos y jefes (último, en espera).

## Pendiente técnico
- [ ] InstanceManager no está conectado: las modalidades usan el enrutador directamente. Conectarlo cuando haya más de una instancia a la vez.
- [ ] Tests nuevos para InstanceRouter, InstanceManager y JefesService.
- [ ] Los tipos MobRegistry.Registry e InstanceRouter.InstanceRouter se importan desde otros módulos: si Studio marca error, revisar primero aquí.
- [ ] Notificaciones: JefesService usa el mismo canal que oleadas (waveFxRemote). El cliente debe ignorar o mostrar los mensajes de kind "end" y "wave_error" de jefes.

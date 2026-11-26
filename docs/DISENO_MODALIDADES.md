# Diseño de modalidades (claude-works)

## Modalidades
1. Dungeons (antes "oleadas"). Siempre disponible, sin requisito de nivel. Dificultad elegible; cada ronda más difícil que la anterior. Usa el mapa de 5 plataformas con puentes.
2. Jefes (nombre pendiente). Elige jefe y dificultad. Máximo 4 jugadores, todos con el nivel mínimo del jefe. Jefes de One Piece y Naruto.
3. En espera (Mapa libre con secretos y jefes: lo último en desarrollarse).

## Reglas
- Niveles: se definen más adelante, ligados a rangos y frutas/jutsus (cada uno con su propia XP).
- Entrada: el jugador debe tener el nivel exigido por sí mismo.
- Dificultad: en Jefes se elige al entrar y no cambia. En Dungeons sube en cada ronda.
- Grupos: invitación o círculo en la plaza.
- Puentes: siempre disponibles (parte del mapa).
- Recompensas: siempre hay premio al matar mobs; mejor cuanto más alta la ronda. Completar una Dungeon da XP fija.
- Mobs de prueba (Lobo de Brasa, Espíritu de Brasa): se reemplazan.

## XP
XP final = XP base x pase x poción x dificultad
- Los modificadores se multiplican entre sí.
- Pociones: duran 10 o 15 min. El tiempo de pociones del mismo tipo se SUMA.
- Cola: si hay varias, la primera se gasta y las siguientes quedan en espera hasta que termine la anterior.
- Pases ejemplo: Oro x2, Suerte VIP, Gemas x2. Pociones de daño, suerte y XP: más adelante.
- XP fija (completar Dungeon) no entra en la fórmula.

## Tienda
Ventana aparte con botón en la barra izquierda, estilo Folk Stud. Secciones: Todo, Pases, Frutas, etc.

## Arquitectura de instancias
- InstanceManager: crea una instancia al entrar, la coloca en un hueco libre del mundo y la destruye al quedarse vacía (margen de 10 s).
- InstanceRouter: relación userId -> instanceId.
- MobRegistry por instancia (fábrica MobRegistry.new). El mundo general conserva el registro "overworld".
- AbilityService recibe registryFor(userId) en lugar de findTarget/findTargetsNear.
- Mapas como plantillas clonadas en un hueco del workspace.
- Trade-off elegido: huecos lejanos en el mismo servidor (sin TeleportService).

## Fases
1. Registro de mobs por instancia (hecho en rama feature/instancias-fase1, archivo MobRegistry.luau).
2. InstanceManager e InstanceRouter; oleadas pasa a ser una instancia.
3. Mapa y reglas de Dungeons.
4. Ventana de tienda con secciones (independiente, puede hacerse en paralelo).
5. Jefes, y después Mapa libre.

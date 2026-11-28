# Cómo probar el proyecto en Roblox Studio

El mundo (suelo, hub, puntos de spawn, plantillas de zombis) lo genera el servidor al arrancar. No hay que crear nada a mano.

## Construir y abrir (PowerShell)

    Set-Location "<carpeta del proyecto>"
    rojo build default.project.json -o roblox-anime.rbxlx
    Invoke-Item roblox-anime.rbxlx

Requiere Rojo 7.7.1 declarado con Rokit en esta carpeta (`rokit install`).

Importante: vuelve a construir el `.rbxlx` cada vez que cambies el proyecto. Si abres un `.rbxlx` antiguo, verás mobs antiguos.

## En Studio

1. Pulsa Play (F5) y mira la ventana de salida.
2. Debe aparecer `[Tests] todas las suites pasaron`.
3. El jugador aparece junto a la fuente, en el centro. En cada punta de la isla central hay un punto de interés enorme sobre un círculo de arena: casas de modalidad al oeste, tienda al este, ruleta al norte y tableros al sur (caminos de adoquín desde la plaza). Los zombis aparecen en las islas de las esquinas (lobos NE, espíritus NO, bruto SE; la aldea SO aún no tiene mobs). Sal de la plaza por el camino de adoquín y cruza el puente de madera bajo el arco con el nombre de la isla.
4. Acércate a menos de 8 studs de un zombi para golpear con la habilidad de alcance corto.

## Combate

Botones abajo o teclas 1 a 4 lanzan habilidades. Arriba aparecen el nombre y la distancia del zombi más cercano.

- 1 Puño de Magma: un golpe cuerpo a cuerpo (alcance 8).
- 2 Tormenta de Ceniza: daño a todos los enemigos en 12 studs alrededor de ti; no hace falta apuntar.
- 3 Lanza de Brasa: un golpe a distancia (alcance 18).
- 4 Clon de Humo: tres golpes seguidos a un mismo enemigo.

Las habilidades 2 y 3 necesitan nivel 10 y la 4 nivel 25, salvo en el modo de pruebas.

## Modo de pruebas

`Shared/Definitions/TestConfig.luau`: sin niveles ni enfriamientos, y las habilidades salen aunque no haya enemigos (daño 0). Está activo hasta tener un mapa definitivo. Para volver al ritmo real, pon `NO_LEVELS` y `NO_COOLDOWNS` en `false`.

## Notas

- El guardado en Studio necesita activar el acceso a los servicios de API del lugar (Configuración del juego → Seguridad). Sin eso, el progreso no se guarda y verás `ProfileStore: Roblox API services unavailable`. Las pruebas unitarias no lo necesitan.
- Botón verde arriba a la derecha: inicia la misión "Primera caza". El progreso y los rechazos se ven en la ventana de salida.

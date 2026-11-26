# Parte 4: mapa nuevo y movimiento de mobs

## Qué cambia
- Mapa de 448 studs (antes 256). Disposición: modalidades al oeste, plaza con fuente al centro, tienda al este, campos de mobs en el anillo exterior.
- Nuevo `World/MapLayout.luau`: plano como datos (zonas, caminos, spawns, altura del terreno). Sin Instances, se prueba sin Studio.
- Nuevo `World/LandmarksBuilder.luau`: tienda (4 puestos con toldo) y arena de modalidades (disco de madera con agua y pilares).
- Decoración (rocas, árboles, brasas y flores) solo se coloca fuera de zonas y caminos.
- Nuevo `Mobs/Pathing.luau`: los mobs calculan su camino con PathfindingService en lugar de ir en línea recta. Si se atascan, descartan el camino y saltan.
- Zombis: solo el torso colisiona; brazos, piernas y cabeza ya no se enganchan en bloques.
- Nuevo test `Tests/MapLayout.spec.luau`, registrado en `RunTests.server.luau`.

## Cómo probar
1. Abre PowerShell en esta carpeta y ejecuta `rojo build default.project.json -o roblox-anime.rbxlx`.
2. Abre el `.rbxlx` y pulsa Play.
3. La salida debe mostrar `[MapLayout]` sin FAIL y después `[Tests] todas las suites pasaron`.
4. Atrae a un zombi detrás de un árbol o una roca: debe rodearlo.

## Pendiente de verificar en Studio
- Que el zombi se mantenga de pie con solo el torso como colisionador.
- Tiempo de carga del mapa de 448 studs.

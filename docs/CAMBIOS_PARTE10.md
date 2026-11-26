# Parte 10: reparto de drops y gemas por daño, e interfaz diagnosticable

## Reparto
- `Mob` registra el daño real de cada jugador (sin contar el exceso del golpe final).
- `Contribution` (nuevo, puro): quien mata solo tiene el 100 % de probabilidad. En grupo, ese 100 % se reparte según el porcentaje de daño de cada uno.
- Objetos: cada contribuyente tira su parte, con su propia suerte de rango.
- Gemas: la probabilidad de cada contribuyente se multiplica por su participación.
- Oro: sigue siendo por contribuyente (sin reparto), porque se habló de probabilidad.

## Interfaz
- `MainHud` imprime `[HUD] iniciando` y `[HUD] lista`. Si no aparece `iniciando`, el script no se está ejecutando.
- Si faltan los remotos de economía, la interfaz se muestra igual y avisa con un aviso.

## Cómo probar
1. `rojo build default.project.json -o roblox-anime.rbxlx` y Play.
2. Debe salir `[Contribution] 10/10 OK` sin FAIL.
3. En la pestaña de Salida, filtra por cliente: debe aparecer `[HUD] iniciando` y `[HUD] lista`.

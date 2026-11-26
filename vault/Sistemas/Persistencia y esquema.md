---
tags: [sistema, datos]
---
# Persistencia y esquema

## Esquema del perfil, versión 4
- v1: nivel e inventario. v2: misiones. v3: XP. v4: oro, gemas y rango.
- Cada versión tiene migración en `MIGRATIONS`. Nunca se editan migraciones publicadas.

## Reglas
- Un perfil que no pasa `validate` no se sobrescribe.
- `snapshotFor` (en `Bootstrap`) construye lo que se guarda. Si le falta un campo, el autoguardado se rechaza.
- ProfileStore con bloqueo de sesión.

## Pendiente
- Activar servicios de API para que el guardado funcione en Studio.

---
tags: [sistema, arquitectura]
---
# Arquitectura

Estilo: arquitecto staff. Clean Code, SOLID y DDD. [[Referencias/Preferencias de trabajo]]

## Capas
- **ReplicatedStorage/Shared/Definitions**: datos puros congelados con `table.freeze`. Mobs, zonas, habilidades, rangos, economía (incluido el cambio), drops, ruleta, misiones, `UiAssets`, **`Shop`** (pases y precios).
- **ReplicatedStorage/Shared/Util**: lógica pura sin Instances. `Result`, `Progression`, `RoundPlanner`, `Rewards`, `Contribution`, **`Perks`**.
- **ReplicatedStorage/FolkStudUI**: kit de interfaz de terceros, con `M.helpers` añadido.
- **ServerScriptService**: servicios con dependencias inyectadas. Punto de entrada: `Bootstrap.server.luau`. Nuevo: **`Monetization/GamePassService`**.
- **StarterPlayerScripts**: interfaz y combate. Solo presentan, no deciden.

## Reglas
- El servidor decide todo: daño, drops, oro, gemas, rangos, misiones, cambios y pases.
- Eventos de dominio en `DomainEvents`: `mobKilled`, `questCompleted`, `itemCollected`.
- Remotos en `Remotes`: CastAbility, StartQuest, CastResult, AbilityFx, RouletteResult, WalletFx, RankUp, **ExchangeCurrency**.
- Atributos del jugador para el cliente: `Level`, `Xp`, `Gold`, `Gems`, `Rank`, y **`Pase_<id>`** (true si lo tiene).

## Herramientas
- Rojo 7.7.1 vía Rokit. `rojo build default.project.json -o roblox-anime.rbxlx`.
- Selene y StyLua: pendientes.

Enlaces: [[Sistemas/Tienda y pases]].

---
tags: [estado, pruebas]
actualizado: 2026-11-26
---
# Pruebas

Corren al pulsar Play en Studio (`RunTests.server.luau`).

## Última ejecución real (parte 16)
| Suite | Resultado |
|---|---|
| AbilityService | OK |
| DropService | OK |
| MobStateMachine | 8/8 |
| Mob | 5/5 |
| Signal | 2/2 (un listener falla a propósito) |
| QuestService | 8/8 |
| SpawnPlanner | 5/5 |
| InventoryService | 6/6 |
| ContentValidator | 8/8 |
| ProfileService | 14/14 |
| MobScheduler | 3/3 (un job falla a propósito) |
| AnimationCritic | 5/5 |
| PlayerPresence | 2/2 |
| Progression | 3/3 |
| Roulette | OK |
| RoundPlanner | OK |
| MapLayout | 6/6 |
| Rewards | 11/11 |
| DropLuck | 4/4 |
| Contribution | 10/10 |

Los fallos "intencionales" de Signal y MobScheduler no son bugs.

## Parte 17 (escritas, sin ejecutar)
- Rewards: +5 pruebas de reparto de oro, +5 de cambio, +4 de pases. Pasa de 11 a 25.
- MapLayout: pasa de 6 a 7.
- WaveSession (suite nueva): 9 pruebas de oleadas, victoria, derrota y jefes.
- GamePassService (suite nueva): 6 pruebas de propiedad, efectos, IDs sin comprar y consulta a Roblox con error.

## Sin cobertura
- Pathing de mobs, interfaz, tienda, pases en Studio: solo se ven en Studio.

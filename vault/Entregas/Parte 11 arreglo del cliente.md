---
tags: [entrega, bug]
---
# Parte 11: arreglo del cliente

**Problema**: la interfaz, la barra de habilidades y la ruleta no llegaban al cliente desde la parte 6.

**Causa**: `default.project.json` apuntaba a `src/StarterPlayerScripts`, pero los scripts estaban en `src/StarterPlayer/StarterPlayerScripts`. Rojo dejó la carpeta vacía sin error.

**Arreglo**: solo la ruta en el proyecto de Rojo.

Enlaces: [[Estado/Bugs y riesgos]].

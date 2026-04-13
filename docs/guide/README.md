# BC-Bench: Guia Paso a Paso para Desarrolladores AL

Guia practica para evaluar agentes de codificacion sobre tareas reales de **Microsoft Dynamics 365 Business Central** usando el framework **BC-Bench**.

Orientada a desarrolladores y equipos del ecosistema Business Central que quieran medir, comparar y mejorar el rendimiento de herramientas de IA en su flujo de trabajo con AL.

---

## Indice

### [Parte 1 - Introduccion y Conceptos Fundamentales](01-introduccion.md)
- Que es BC-Bench y para que sirve
- Arquitectura del repositorio
- Conceptos clave: categorias, agentes, escenarios
- Estructura del dataset (101 bugs reales de BC)
- Flujo de evaluacion completo

### [Parte 2 - Instalacion, Setup y Primera Evaluacion](02-setup-y-primera-evaluacion.md)
- Requisitos previos (software, credenciales)
- Instalacion paso a paso
- Explorando el dataset (`bcbench dataset list/view/review`)
- Tu primera evaluacion: modo rapido (solo patch) y modo completo (build + tests)
- Modelos disponibles por agente

### [Parte 3 - Configuracion de Agentes y Personalizacion](03-configuracion-de-agentes.md)
- El fichero de configuracion central (`config.yaml`)
- Plantillas de prompt y como personalizarlas
- Custom instructions (CLAUDE.md / copilot-instructions.md)
- Skills: modulos de conocimiento especializado
- Agentes personalizados: developer, conductor, bugfix-firstline
- Servidores MCP (AL Tool, Microsoft Learn)
- Tabla resumen: que modificar para cada experimento

### [Parte 4 - Comparacion de Baselines y Scripts para VM](04-baselines-y-scripts-vm.md)
- Preparar una VM Windows para evaluacion (2 fases)
- Setup del contenedor BC y repositorio
- Script `Setup-ALDCEvaluation.ps1`: evaluaciones individuales y comparativas
- Script `Run-FullComparison.ps1`: comparacion completa multi-agente (8 escenarios)
- Ejemplos listos para usar en produccion

### [Parte 5 - Obtencion, Analisis y Documentacion de Resultados](05-resultados-y-analisis.md)
- Estructura de ficheros de resultado
- Comandos CLI: summarize, aggregate, review, update
- Metricas estadisticas (pass rate, bootstrap CI, pass@k)
- Analisis visual con Jupyter notebooks
- Workflow completo: de la evaluacion al informe
- Versionado y compatibilidad de resultados
- Troubleshooting comun

---

## Referencia Rapida

```bash
# Explorar dataset
uv run bcbench dataset list
uv run bcbench dataset view microsoft__BCApps-4822 --show-patch

# Ejecutar agente (solo patch, sin contenedor)
uv run bcbench run claude microsoft__BCApps-4822 --category bug-fix --model claude-sonnet-4-6

# Evaluacion completa (requiere contenedor BC)
uv run bcbench evaluate claude microsoft__BCApps-4822 --category bug-fix --model claude-sonnet-4-6 --container-name bcbench --username admin --password "Pass!"

# Resumir resultados
uv run bcbench result summarize mi_run_id
uv run bcbench result aggregate --input-dir directorio/resultados/

# Revisar fallos interactivamente
uv run bcbench result review resultados.jsonl --category bug-fix
```

---

## Requisitos

- Python 3.13+ con [uv](https://docs.astral.sh/uv/)
- Git 2.40+
- Node.js 22+ (para Claude Code)
- Windows Server con Docker/Hyper-V (para evaluacion completa con contenedor BC)
- API keys: `ANTHROPIC_API_KEY` y/o `GITHUB_TOKEN`

---

> BC-Bench es open-source ([MIT License](https://github.com/microsoft/BC-Bench)). Fork y adapta a tus necesidades.

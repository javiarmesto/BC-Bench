---
layout: default
title: "Parte 1 — Introduccion"
lang: es
---

# BC-Bench: Guia Paso a Paso

## Parte 1 - Introduccion y Conceptos Fundamentales

---

## Que es BC-Bench?

BC-Bench es un **framework de benchmarking open-source** creado por Microsoft para evaluar agentes de codificacion (coding agents) sobre tareas reales de desarrollo en **Microsoft Dynamics 365 Business Central** usando el lenguaje **AL**.

Esta inspirado en [SWE-Bench](https://github.com/swe-bench/SWE-bench), el benchmark de referencia para evaluar agentes de IA en tareas de ingenieria de software, pero adaptado al ecosistema de Business Central con sus particularidades: compilacion de apps AL, contenedores BC, tests de codeunits, y la estructura de proyectos propia de BCApps.

### Para que sirve?

BC-Bench permite responder preguntas concretas como:

- **"Que modelo resuelve mas bugs reales de BC?"** - Comparar Claude Sonnet vs Opus vs GPT en tareas identicas
- **"Mejoran las instrucciones personalizadas el resultado?"** - Medir el impacto de custom instructions, skills y agentes especializados
- **"Aporta valor el servidor MCP de AL?"** - Cuantificar si dar al agente acceso al compilador AL mejora su rendimiento
- **"Que configuracion de agente es la mejor para mi equipo?"** - Iterar rapidamente sobre distintas configuraciones y comparar resultados

### Como funciona a alto nivel?

```
1. DATASET: 101 bugs reales de Business Central con sus parches gold y tests
       |
2. AGENTE: Un coding agent (Claude Code, Copilot CLI, mini-bc-agent) intenta resolver el bug
       |
3. EVALUACION: Se aplica el test patch, se compila y se ejecutan los tests en un contenedor BC
       |
4. RESULTADO: resolved/failed + metricas (tokens, tiempo, herramientas usadas)
```

Cada tarea del dataset viene de un bug real reportado en el repositorio de BCApps o NAV. El dataset incluye:
- El **problem statement** (descripcion del bug, pasos de reproduccion, capturas)
- El **base_commit** (el estado del codigo antes del fix)
- El **patch** (la solucion gold standard)
- El **test_patch** (tests que validan si el fix es correcto)
- Los **tests FAIL_TO_PASS** (que deben fallar sin el fix y pasar con el)

---

## Arquitectura del Repositorio

```
BC-Bench/
|-- src/bcbench/           # Harness de evaluacion (Python)
|   |-- agent/             # Implementaciones de agentes (mini, claude, copilot)
|   |   |-- shared/        # Configuracion compartida: prompts, skills, instrucciones
|   |   |   |-- config.yaml           # Configuracion principal de agentes
|   |   |   |-- instructions/         # Custom instructions por repositorio
|   |   |       |-- microsoft-BCApps/ # Instrucciones, skills, agentes para BCApps
|   |   |       |-- microsoftInternal-NAV/  # Instrucciones para NAV
|   |   |-- mini/          # mini-bc-agent (baseline minimo)
|   |   |-- claude/        # Integracion Claude Code
|   |   |-- copilot/       # Integracion GitHub Copilot CLI
|   |-- commands/          # Comandos CLI (run, evaluate, dataset, result)
|   |-- evaluate/          # Pipelines de evaluacion (bug-fix, test-generation)
|   |-- results/           # Clases de resultado, metricas, leaderboard
|   |-- operations/        # Operaciones BC (build, test, git, setup)
|-- dataset/
|   |-- bcbench.jsonl      # Dataset principal (101 entradas)
|   |-- problemstatement/  # Problem statements con README.md e imagenes
|-- scripts/               # Scripts PowerShell para VM y evaluacion
|-- notebooks/             # Jupyter notebooks para analisis de resultados
|-- docs/                  # Documentacion y leaderboard
|-- tests/                 # Tests unitarios del harness
```

---

## Conceptos Clave

### Categorias de Evaluacion

BC-Bench soporta dos categorias:

| Categoria | Que hace el agente | Como se evalua |
|-----------|-------------------|----------------|
| **bug-fix** | Recibe la descripcion del bug y debe producir el parche que lo corrige | Se aplica el test_patch, se compila, se ejecutan los tests. Si pasan: resolved |
| **test-generation** | Recibe el bug (y opcionalmente el fix) y debe generar tests que lo reproduzcan | Los tests deben FALLAR contra codigo sin fix y PASAR con el fix aplicado |

### Agentes Disponibles

| Agente | Descripcion | Uso Principal |
|--------|------------|---------------|
| **mini-bc-agent** | Loop minimo basado en mini-swe-agent. Solo PowerShell. | Baseline de referencia |
| **Claude Code** | Herramienta agentica de Anthropic. Soporta MCP, custom instructions, agentes. | Evaluacion avanzada |
| **GitHub Copilot CLI** | CLI de GitHub Copilot. Soporta MCP, tools, agent mode. | Evaluacion avanzada |

### Escenarios de Comparacion

Un **escenario** es una combinacion de agente + configuracion. Los escenarios tipicos son:

| Escenario | Que incluye |
|-----------|------------|
| **baseline** | Agente sin instrucciones personalizadas, sin skills, sin agentes custom |
| **con instrucciones** | Agente + custom instructions (CLAUDE.md o copilot-instructions.md) |
| **con instrucciones + skills** | Agente + instrucciones + skills especializados (bugfix, debug, testing...) |
| **con agente especializado** | Todo lo anterior + un agente custom (al-developer-bench, al-conductor-bench...) |

### Estructura de una Entrada del Dataset

Cada linea del fichero `dataset/bcbench.jsonl` es un JSON con esta estructura:

```json
{
  "instance_id": "microsoft__BCApps-4822",
  "repo": "microsoft/BCApps",
  "base_commit": "a1b2c3d4...",
  "created_at": "2025-01-15",
  "environment_setup_version": "26.0",
  "project_paths": [
    "App\\Apps\\W1\\Shopify\\app",
    "App\\Apps\\W1\\Shopify\\test"
  ],
  "FAIL_TO_PASS": [
    {
      "codeunitID": 139648,
      "functionName": ["UnitTestSuggestShopifyPaymentsFailedTransaction"]
    }
  ],
  "PASS_TO_PASS": [],
  "patch": "--- a/...\n+++ b/...\n@@ ...",
  "test_patch": "--- a/...\n+++ b/...\n@@ ...",
  "metadata": {
    "area": "shopify",
    "image_count": 3
  }
}
```

Campos importantes:
- **instance_id**: Identificador unico. Formato: `{repo}__{issue-number}`
- **base_commit**: SHA del commit donde el bug existe (antes del fix)
- **environment_setup_version**: Version de BC necesaria (ej: "26.0" = BC 2025 Wave 1)
- **project_paths**: Directorios AL afectados (siempre incluye app + test)
- **FAIL_TO_PASS**: Tests que deben fallar sin fix y pasar con el
- **patch**: El parche gold standard (la solucion correcta)
- **test_patch**: Parche que anade los tests de validacion

### Problem Statements

Cada entrada tiene un directorio en `dataset/problemstatement/{instance_id}/` con:
- `README.md` - Descripcion del bug, pasos de reproduccion, resultado esperado vs actual
- Imagenes PNG - Capturas de pantalla del bug (referenciadas desde el README)

Ejemplo tipico de un problem statement:

```markdown
# Title: Shopify - Export customer as location - Sell-to and Bill-to are missing
## Repro Steps:
1. Export two companies to Shopify
2. One normal, another with a different bill-to defined
...
**ACTUAL RESULT:** Sell-to and Bill-to fields are empty
**EXPECTED RESULT:** Fields should be populated correctly
```

---

## Flujo de Evaluacion Completo

Este es el flujo que sigue cada evaluacion individual (para bug-fix):

```
1. SETUP
   |-- Limpiar repositorio (git clean, checkout base_commit)
   |-- Copiar problem statement al repo
   |-- Compilar proyectos base (timeout: 30 min BaseApp, 5 min apps)
   |-- Copiar instrucciones/skills/agentes (si estan habilitados)

2. EJECUCION DEL AGENTE
   |-- Construir prompt con el task y contexto
   |-- Configurar MCP servers (si --al-mcp esta habilitado)
   |-- Ejecutar agente (timeout: 60 min)
   |-- Capturar metricas: tokens, tiempo, herramientas, turnos

3. EVALUACION
   |-- Capturar parche generado por el agente (git diff)
   |-- Aplicar test_patch (anade los tests de validacion)
   |-- Compilar con los tests (timeout: 5 min)
   |-- Ejecutar tests (timeout: 3 min por test)
   |-- Determinar resultado: resolved / build-failure / test-failure

4. RESULTADO
   |-- Guardar en {instance_id}.jsonl
   |-- Incluye: resolved, build, patch, metricas, configuracion
```

### Timeouts por Defecto

| Operacion | Timeout |
|-----------|---------|
| Compilacion BaseApp | 30 minutos |
| Compilacion App | 5 minutos |
| Ejecucion de tests | 3 minutos |
| Ejecucion del agente | 60 minutos |

---

> **Siguiente**: [Parte 2 - Instalacion, Setup y Primera Evaluacion](02-setup-y-primera-evaluacion.md)

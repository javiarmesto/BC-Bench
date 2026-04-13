---
layout: default
title: "Parte 2 — Setup"
lang: es
---

# BC-Bench: Guia Paso a Paso

## Parte 2 - Instalacion, Setup y Primera Evaluacion

---

## Requisitos Previos

### Software Necesario

| Herramienta | Version Minima | Para que |
|-------------|---------------|----------|
| [uv](https://docs.astral.sh/uv/) | Ultima | Gestor de paquetes Python (reemplaza pip/venv) |
| Python | 3.13+ | Runtime del harness |
| Git | 2.40+ | Gestion del repositorio |
| Node.js | 22+ | Necesario para Claude Code |
| Docker + Hyper-V | - | Contenedores Business Central (solo Windows) |
| PowerShell | 7+ | Scripts de evaluacion (solo Windows) |

### Herramientas de Agente (segun cual uses)

| Agente | Instalacion | Variable de entorno |
|--------|------------|-------------------|
| Claude Code | `npm install -g @anthropic-ai/claude-code` | `ANTHROPIC_API_KEY` |
| GitHub Copilot CLI | Via GitHub CLI | `GITHUB_TOKEN` |
| mini-bc-agent | Incluido en BC-Bench | `AZURE_API_KEY`, `AZURE_API_BASE` |

### Modulos PowerShell (para evaluacion con contenedor BC)

| Modulo | Para que |
|--------|----------|
| BcContainerHelper | Crear y gestionar contenedores Business Central |
| AL Tool (dotnet tool) | Servidor MCP de AL (compilacion, analisis) |

---

## Instalacion Paso a Paso

### Paso 1: Clonar el repositorio

```bash
# Fork y clone (recomendado para uso propio)
gh repo fork microsoft/BC-Bench --clone
cd BC-Bench

# O clone directo
git clone https://github.com/microsoft/BC-Bench.git
cd BC-Bench
```

### Paso 2: Instalar Python y dependencias

```bash
# Instalar Python 3.13 via uv
uv python install

# Instalar todas las dependencias (incluye dev y analysis)
uv sync --all-groups

# Instalar hooks de pre-commit
uv run pre-commit install
```

### Paso 3: Verificar la instalacion

```bash
# Mostrar ayuda del CLI
uv run bcbench --help
```

Deberias ver:

```
Usage: bcbench [OPTIONS] COMMAND [ARGS]...

BC-Bench: Benchmarking tool for Business Central (AL) ecosystem

Commands:
  collect    Collect dataset entries
  dataset    Query and analyze dataset
  evaluate   Evaluate agents on benchmark datasets
  result     Process and display evaluation results
  run        Run agents on single dataset entry
```

### Paso 4: Configurar variables de entorno

Copia el archivo de ejemplo y rellena tus credenciales:

```bash
cp .env.sample .env
```

Variables clave en `.env`:

```ini
# Para Claude Code
ANTHROPIC_API_KEY=sk-ant-...

# Para GitHub Copilot CLI
GITHUB_TOKEN=ghp_...

# Para mini-bc-agent (Azure AI Foundry)
AZURE_API_KEY=...
AZURE_API_BASE=...
AZURE_API_VERSION=...

# Para contenedores BC (evaluacion completa)
BC_CONTAINER_NAME=bcbench
BC_CONTAINER_USERNAME=admin
BC_CONTAINER_PASSWORD=TuPassword123!
```

---

## Explorando el Dataset

Antes de lanzar una evaluacion, familiarizate con el dataset.

### Listar todas las entradas

```bash
uv run bcbench dataset list
```

Esto muestra las 101 entradas disponibles:

```
Found 101 entry(ies):
  - microsoftInternal__NAV-210528
  - microsoftInternal__NAV-224009
  - microsoft__BCApps-4822
  ...
```

### Ver detalle de una entrada

```bash
uv run bcbench dataset view microsoft__BCApps-4822
```

Muestra informacion detallada: repo, commit, version BC, project paths, tests, y el problem statement.

Para ver tambien el parche gold:

```bash
uv run bcbench dataset view microsoft__BCApps-4822 --show-patch
```

### Revisar el dataset con TUI interactiva

```bash
uv run bcbench dataset review
```

Abre una interfaz de terminal con vista dividida: informacion de la entrada a la izquierda, problem statement a la derecha. Usa las flechas para navegar entre entradas.

Para ver tambien estadisticas de resolucion (si tienes resultados previos):

```bash
uv run bcbench dataset review --results-dir notebooks/result/bug-fix/mi-directorio/
```

---

## Tu Primera Evaluacion

Hay dos modos de ejecucion:

| Modo | Comando | Que hace | Necesita contenedor BC? |
|------|---------|----------|------------------------|
| **run** | `bcbench run` | Solo ejecuta el agente y genera el parche | No |
| **evaluate** | `bcbench evaluate` | Ejecuta el agente + compila + ejecuta tests | Si |

### Modo rapido: solo generar el parche (sin contenedor)

Este modo es ideal para empezar. No necesitas contenedor BC, solo el agente y el repositorio de BCApps clonado localmente.

#### Con Claude Code

```bash
uv run bcbench run claude microsoft__BCApps-4822 \
  --category bug-fix \
  --model claude-sonnet-4-6 \
  --container-name bcbench \
  --repo-path /ruta/a/BCApps
```

#### Con GitHub Copilot CLI

```bash
uv run bcbench run copilot microsoft__BCApps-4822 \
  --category bug-fix \
  --model claude-sonnet-4.6 \
  --container-name bcbench \
  --repo-path /ruta/a/BCApps
```

#### Con mini-bc-agent

```bash
uv run bcbench run mini microsoft__BCApps-4822 \
  --category bug-fix \
  --model gpt-5.1-codex-mini \
  --repo-path /ruta/a/BCApps
```

> **Nota sobre modelos**: Claude Code usa guiones (`claude-sonnet-4-6`), Copilot usa puntos (`claude-sonnet-4.6`). Son formatos distintos del mismo modelo.

### Modo completo: evaluacion con build + tests

Este modo requiere un contenedor Business Central en ejecucion (Windows con Docker/Hyper-V).

```bash
uv run bcbench evaluate claude microsoft__BCApps-4822 \
  --category bug-fix \
  --model claude-sonnet-4-6 \
  --container-name bcbench \
  --username admin \
  --password "TuPassword123!" \
  --repo-path C:\depot\BCApps \
  --run-id mi_primera_evaluacion
```

Parametros clave:

| Parametro | Descripcion |
|-----------|------------|
| `--category` | `bug-fix` o `test-generation` |
| `--model` | Modelo LLM a usar |
| `--container-name` | Nombre del contenedor BC |
| `--run-id` | Identificador unico para esta ejecucion |
| `--al-mcp` | Habilitar el servidor MCP de AL (acceso al compilador) |
| `--output-dir` | Directorio donde guardar resultados |

### Habilitar el servidor MCP de AL

El flag `--al-mcp` da al agente acceso al compilador AL via MCP (Model Context Protocol). Esto le permite compilar y obtener errores de compilacion durante su ejecucion:

```bash
uv run bcbench evaluate claude microsoft__BCApps-4822 \
  --category bug-fix \
  --model claude-sonnet-4-6 \
  --container-name bcbench \
  --username admin \
  --password "TuPassword123!" \
  --al-mcp
```

> **Requisito**: El AL Tool debe estar instalado: `dotnet tool install -g Microsoft.Dynamics.BusinessCentral.Development.Tools`

---

## Modelos Disponibles

### Para Claude Code

| Modelo | ID |
|--------|-----|
| Claude Sonnet 4.6 | `claude-sonnet-4-6` |
| Claude Opus 4.6 | `claude-opus-4-6` |
| Claude Haiku 4.5 | `claude-haiku-4-5` |

### Para GitHub Copilot CLI

| Modelo | ID |
|--------|-----|
| Claude Sonnet 4.6 | `claude-sonnet-4.6` |
| Claude Opus 4.6 | `claude-opus-4.6` |
| Claude Haiku 4.5 | `claude-haiku-4.5` |
| GPT 5.4 | `gpt-5.4` |
| GPT 5.2 | `gpt-5.2` |
| GPT 4.1 | `gpt-4.1` |

### Para mini-bc-agent

| Modelo | ID |
|--------|-----|
| GPT 5.1 Codex Mini | `gpt-5.1-codex-mini` |

---

## Que Esperar del Resultado

Tras la evaluacion, el resultado se guarda en un fichero JSONL (`{instance_id}.jsonl`) con esta estructura:

```json
{
  "instance_id": "microsoft__BCApps-4822",
  "model": "claude-sonnet-4-6",
  "agent_name": "Claude Code",
  "category": "bug-fix",
  "resolved": true,
  "build": true,
  "timeout": false,
  "generated_patch": "--- a/...\n+++ b/...",
  "error_message": null,
  "metrics": {
    "execution_time": 145.3,
    "llm_duration": 120.5,
    "turn_count": 12,
    "prompt_tokens": 450000,
    "completion_tokens": 3500,
    "tool_usage": {
      "Read": 15,
      "Grep": 8,
      "Edit": 3,
      "Glob": 5
    }
  },
  "experiment": {
    "mcp_servers": ["altool", "mslearn"],
    "custom_instructions": true,
    "skills_enabled": true,
    "custom_agent": "al-developer-bench"
  }
}
```

Campos de resultado:
- **resolved**: `true` si el agente resolvio el bug (los tests pasan)
- **build**: `true` si el codigo compilo correctamente
- **timeout**: `true` si el agente excedio el timeout de 60 minutos
- **metrics**: Metricas de ejecucion detalladas
- **experiment**: Configuracion exacta usada (para reproducibilidad)

---

> **Siguiente**: [Parte 3 - Configuracion de Agentes y Personalizacion](03-configuracion-de-agentes.md)

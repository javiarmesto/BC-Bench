---
layout: default
title: "Parte 5 — Resultados"
lang: es
---

# BC-Bench: Guia Paso a Paso

## Parte 5 - Obtencion, Analisis y Documentacion de Resultados

---

## Estructura de los Resultados

Tras una evaluacion, los resultados se guardan en el directorio de salida con esta estructura:

```
evaluation_results/
|-- {run_id}/
    |-- {instance_id}.jsonl          # Resultado por instancia
    |-- evaluation_summary.json      # Resumen agregado
    |-- bceval_results.jsonl         # Exportacion formato bceval
    |-- claude_debug.log             # Log de debug (Claude Code)
    |-- copilot-*.log                # Log de debug (Copilot)
```

Cada fichero `.jsonl` contiene una linea JSON por resultado con:

```json
{
  "instance_id": "microsoft__BCApps-4822",
  "project": "BCApps",
  "model": "claude-sonnet-4-6",
  "agent_name": "Claude Code",
  "category": "bug-fix",
  "resolved": true,
  "build": true,
  "timeout": false,
  "generated_patch": "--- a/...\n+++ b/...",
  "error_message": null,
  "benchmark_version": "0.4.0",
  "metrics": {
    "execution_time": 145.3,
    "llm_duration": 120.5,
    "turn_count": 12,
    "prompt_tokens": 450000,
    "completion_tokens": 3500,
    "tool_usage": { "Read": 15, "Grep": 8, "Edit": 3 }
  },
  "experiment": {
    "mcp_servers": ["altool"],
    "custom_instructions": true,
    "skills_enabled": true,
    "custom_agent": "al-developer-bench"
  }
}
```

---

## Comandos de Resultado del CLI

### Resumir una ejecucion

```bash
uv run bcbench result summarize {run_id}
```

Lee todos los ficheros `.jsonl` del directorio `evaluation_results/{run_id}/`, calcula metricas agregadas y muestra un resumen en consola:

- Total de instancias evaluadas
- Resueltas vs fallidas
- Tasa de compilacion exitosa
- Medias de tokens, tiempo, turnos
- Tasa de exito (pass rate)

Tambien genera:
- `evaluation_summary.json` - Resumen en formato JSON
- `bceval_results.jsonl` - Exportacion para analisis externo

### Agregar resultados de un directorio

```bash
uv run bcbench result aggregate --input-dir notebooks/result/bug-fix/mi-directorio/
```

Similar a `summarize`, pero no requiere un `run_id` especifico. Escanea recursivamente el directorio buscando todos los ficheros `.jsonl` de resultado.

### Revisar resultados con TUI interactiva

```bash
# Revisar todos los resultados no resueltos de un fichero
uv run bcbench result review resultados.jsonl --category bug-fix

# Revisar una instancia especifica en todos los runs de un directorio
uv run bcbench result review notebooks/result/bug-fix/ \
  --category bug-fix \
  --instance-id microsoft__BCApps-4822

# Incluir tambien los resueltos
uv run bcbench result review resultados.jsonl \
  --category bug-fix \
  --include-resolved
```

La TUI muestra una vista dividida: parche esperado (gold) vs parche generado (agente). Usa `j/k` o flechas para navegar, `1-7` para clasificar categorias de fallo.

### Actualizar el leaderboard

```bash
uv run bcbench result update evaluation_results/{run_id}/evaluation_summary.json
```

Toma el resumen de una ejecucion y lo anade al leaderboard publico en `docs/_data/{category}.json`. Almacena hasta 5 runs por combinacion de agente + modelo + configuracion.

### Refrescar agregados del leaderboard

```bash
uv run bcbench result refresh
```

Recalcula las metricas agregadas del leaderboard sin anadir datos nuevos. Util cuando cambia la logica de agregacion.

---

## Metricas Estadisticas

BC-Bench calcula metricas estadisticas avanzadas:

### Pass Rate

```
pass_rate = resolved / total * 100
```

La metrica basica: porcentaje de instancias resueltas.

### Bootstrap Confidence Intervals

BC-Bench usa bootstrapping BCa (bias-corrected and accelerated) para calcular intervalos de confianza al 95%. Esto permite responder: "Con que confianza podemos decir que la tasa de exito es X%?"

### Pass@k

Probabilidad de obtener al menos 1 solucion correcta en k intentos:

```
pass@k = 1 - C(n-c, k) / C(n, k)
```

Donde `n` = total, `c` = correctos. Util cuando ejecutas multiples runs del mismo escenario.

### Pass^k

Probabilidad de que TODOS los k intentos sean correctos:

```
pass^k = estimacion de la probabilidad de exito consistente
```

---

## Analisis con Notebooks

BC-Bench incluye Jupyter notebooks para analisis visual de resultados:

```
notebooks/
|-- dataset.ipynb                        # Estadisticas del dataset
|-- bug-fix/
|   |-- overview.ipynb                   # Vista general bug-fix
|   |-- claude-vs-copilot.ipynb          # Comparacion Claude vs Copilot
|   |-- failure-analysis.ipynb           # Analisis de fallos
|   |-- altool-comparison.ipynb          # Impacto del AL MCP
|   |-- claude-code-aldc-comparison.ipynb  # Comparacion con/sin configuracion personalizada
|   |-- aldc-comparison-full.ipynb       # Comparacion completa de escenarios
|-- test-generation/
    |-- overview.ipynb                   # Vista general test-generation
    |-- altest-comparison.ipynb          # Comparacion de configuraciones
```

### Ejecutar notebooks

```bash
# Instalar dependencias de analisis
uv sync --group analysis

# Lanzar Jupyter
uv run jupyter lab
```

Las dependencias de analisis incluyen: `pandas`, `plotly`, `ipykernel`, `nbformat`.

### Datos del leaderboard

Los notebooks leen los datos agregados de:

```
docs/_data/bug-fix.json
docs/_data/test-generation.json
```

Estructura del leaderboard:

```json
{
  "runs": [
    {
      "total": 101,
      "resolved": 57,
      "failed": 44,
      "build": 100,
      "percentage": 56.4,
      "date": "2026-01-29",
      "model": "claude-opus-4-5",
      "agent_name": "Claude Code",
      "category": "bug-fix",
      "average_duration": 197.3,
      "average_prompt_tokens": 685413.2,
      "average_completion_tokens": 4821.8,
      "instance_results": {
        "microsoftInternal__NAV-204450": false,
        "microsoftInternal__NAV-179733": true
      }
    }
  ],
  "aggregate": [...]
}
```

---

## Workflow Completo: De la Evaluacion al Informe

### Paso 1: Ejecutar la evaluacion

```powershell
# En la VM
.\scripts\Run-FullComparison.ps1 `
  -InstanceIds @("microsoft__BCApps-4822") `
  -LlmFamily sonnet `
  -OnlyMissing
```

### Paso 2: Recopilar y resumir resultados

```bash
# En tu maquina de desarrollo
uv run bcbench result aggregate --input-dir notebooks/result/bug-fix/claude-baseline-sonnet-4-6/
uv run bcbench result aggregate --input-dir notebooks/result/bug-fix/claude-aldc-developer-sonnet-4-6/
```

### Paso 3: Actualizar leaderboard

```bash
uv run bcbench result update evaluation_results/mi_run/evaluation_summary.json
```

### Paso 4: Revisar fallos

```bash
# Revisar instancias que fallaron
uv run bcbench result review notebooks/result/bug-fix/claude-baseline-sonnet-4-6/ \
  --category bug-fix \
  --instance-id microsoft__BCApps-4822
```

### Paso 5: Analisis visual con notebooks

```bash
uv run jupyter lab notebooks/bug-fix/overview.ipynb
```

---

## Versionado de Resultados

BC-Bench usa [versionado semantico](https://semver.org/). La version actual se define en `pyproject.toml`:

```toml
[project]
version = "0.4.0"
```

### Reglas de versionado

| Tipo de cambio | Bump | Ejemplos |
|---------------|------|----------|
| **Major** (X.0.0) | Cambios en dataset o metodologia | Anadir/eliminar entradas, cambiar criterios de pass |
| **Minor** (0.X.0) | Cambios en tooling que afecten resultados | Actualizar version de Copilot, cambiar prompts de agente |
| **Patch** (0.0.X) | Fixes y documentacion | Corregir un bug de parsing, actualizar docs |

### Compatibilidad entre versiones

**Los resultados de versiones distintas NO se pueden agregar juntos.** El comando `bcbench result update` valida que todos los runs tengan el mismo `benchmark_version`. Esto asegura que el leaderboard siempre compara manzanas con manzanas.

---

## Checklist para Documentar una Evaluacion

Al documentar los resultados de una evaluacion, asegurate de incluir:

- [ ] **Fecha** de la evaluacion
- [ ] **Version de BC-Bench** usada (`pyproject.toml`)
- [ ] **Instancias evaluadas** (IDs del dataset)
- [ ] **Modelo LLM** y version
- [ ] **Agente** (Claude Code, Copilot, mini-bc-agent)
- [ ] **Escenario** (baseline, developer, conductor, bugfix)
- [ ] **Categoria** (bug-fix, test-generation)
- [ ] **AL MCP** habilitado o no
- [ ] **Tabla de resultados** (resolved, build, tokens, tiempo)
- [ ] **Observaciones** sobre fallos relevantes
- [ ] **Comparativa** con baseline u otros escenarios

---

## Troubleshooting Comun

### El agente excede el timeout de 60 minutos

- Verifica que el modelo sea adecuado (Haiku es mas rapido que Opus)
- Revisa si el agente esta atascado en un loop (usa `bcbench run mini-inspector` para trajectories)

### Error de compilacion (build: false)

- Verifica la version de BC del contenedor vs `environment_setup_version`
- Asegurate de que el repositorio esta en el `base_commit` correcto

### API overloaded_error

- Usa `-PauseBetweenScenarios 180` (3 minutos entre escenarios)
- O ejecuta escenarios manualmente con pausas

### Contenedor no responde

- Verifica: `docker ps` para ver si esta corriendo
- Recrea: elimina con `docker rm -f bcbench` y vuelve a ejecutar el setup

### Resultados de versiones distintas no se pueden agregar

- Asegurate de que todos los runs usen la misma version de BC-Bench
- Si cambiaste algo que afecta resultados, bumpa la version en `pyproject.toml`

---

> **Volver al indice**: [Indice de la Guia](README.md)

# Evaluando ALDC con BC-Bench: Midiendo el impacto real de instrucciones AI en Business Central

> **Estado:** Diseño e integración completados. Pendiente de ejecución y validación con infraestructura BC.

---

## Introducción

¿Cuánto mejora realmente un agente de IA cuando le das instrucciones especializadas? ¿Las skills de dominio marcan diferencia o solo añaden ruido al contexto?

Este artículo documenta cómo integramos [ALDC (AL Development Collection)](https://github.com/javiarmesto/ALDC-AL-Development-Collection) en [BC-Bench](https://github.com/javiarmesto/bc-bench), el framework de benchmarking de Microsoft para agentes de codificación AL, con el objetivo de medir de forma objetiva el impacto de un framework de instrucciones estructurado sobre el rendimiento de agentes como Claude Code y GitHub Copilot en tareas reales de Business Central.

**Lo que se ha hecho:**
- Análisis completo de ambos proyectos
- Integración de los agentes, skills y reglas de ALDC en la estructura de BC-Bench
- Script de automatización para setup de infraestructura y evaluación
- Configuración lista para ejecutar

**Lo que falta:**
- Ejecutar la evaluación en un entorno con contenedor de Business Central
- Comparar resultados ALDC vs baseline
- Analizar métricas

---

## ¿Qué es BC-Bench?

[BC-Bench](https://learn.microsoft.com/en-us/dynamics365/release-plan/2026wave1/smb/dynamics365-business-central/evaluate-al-coding-agents-bc-bench) es un framework de benchmarking creado por Microsoft, inspirado en [SWE-Bench](https://github.com/swe-bench/SWE-bench), que evalúa agentes de IA en tareas reales de desarrollo AL (Application Language) para Dynamics 365 Business Central.

### Cómo funciona

1. **Dataset**: ~100 tareas extraídas de PRs reales (bugs corregidos, tests creados)
2. **Setup**: Coloca el repositorio en el estado previo al fix (commit base)
3. **Agente**: Ejecuta un agente de IA (Claude Code, Copilot CLI o Mini-BC-Agent) para que intente resolver el problema
4. **Validación**: Compila el código en un contenedor de BC y ejecuta los tests
5. **Resultado**: Si los tests pasan, el agente resolvió el problema

### Categorías de evaluación

| Categoría | Tarea del agente | Criterio de éxito |
|---|---|---|
| **bug-fix** | Arreglar un bug descrito en un issue | Los tests FAIL_TO_PASS pasan + los PASS_TO_PASS siguen pasando |
| **test-generation** | Generar tests para verificar un fix | Los tests generados fallan sin el fix y pasan con él |

### Lo que mide

- **% de resolución** (pass rate)
- Tiempo de ejecución
- Consumo de tokens (prompt + completion)
- Uso de herramientas
- Errores de compilación vs errores de tests vs timeouts

---

## ¿Qué es ALDC?

[ALDC (AL Development Collection)](https://github.com/javiarmesto/ALDC-AL-Development-Collection) es un framework de desarrollo estructurado para Business Central que transforma cómo los agentes de IA abordan el código AL.

En lugar de "vibe coding" (generar código ad-hoc), ALDC proporciona:

### 4 agentes especializados

| Agente | Rol | Cuándo se usa |
|---|---|---|
| **al-architect** | Diseño de soluciones, modelado de datos | Features de complejidad MEDIA/ALTA |
| **al-developer** | Implementación táctica, debugging, fixes | Bug fixes, features simples |
| **al-conductor** | Orquestación TDD con subagentes | Ciclos completos de desarrollo |
| **al-presales** | Estimación PERT, análisis SWOT | Scoping de proyectos |

### 11 skills de dominio

Módulos de conocimiento composables que los agentes cargan bajo demanda:

- **skill-testing**: Patrones Given/When/Then, Library codeunits, TDD
- **skill-debug**: Snapshot debugging, CPU profiling, análisis de causa raíz
- **skill-api**: API Pages v2.0, OData, acciones bound/unbound
- **skill-performance**: SetLoadFields, FlowField optimization, batch processing
- **skill-events**: Event subscribers/publishers, patrón IsHandled
- **skill-permissions**: Permission sets, XLIFF, seguridad role-based
- **skill-pages**: Card, List, Document pages, FastTabs, acciones
- **skill-copilot**: Features de IA, PromptDialog, Azure OpenAI
- **skill-migrate**: Migración entre versiones de BC, upgrade codeunits
- **skill-translate**: Traducción XLF, NAB AL Tools
- **skill-estimation**: Estimación PERT, scoring de complejidad

### 8 reglas de coding (auto-aplicadas)

Estándares que se aplican automáticamente a archivos `*.al`:
- `al-guidelines`, `al-code-style`, `al-naming-conventions`, `al-performance`
- `al-error-handling`, `al-events`, `al-testing`, `al-agent-toolkit`

### Principios fundamentales

- **Extension-only**: Nunca modificar objetos base, usar extensions y event subscribers
- **TDD / spec-driven**: Tests primero (RED), código mínimo (GREEN), refactor (REFACTOR)
- **Human-in-the-Loop**: Gates de aprobación humana en decisiones críticas
- **Least privilege**: Permisos mínimos, XLIFF para strings de usuario

---

## La pregunta: ¿ALDC mejora el rendimiento de los agentes?

BC-Bench está diseñado exactamente para responder esta pregunta. Su filosofía es *"cuantificar el impacto de cambios en tooling"* — midiendo antes y después con las mismas tareas.

### Hipótesis

Un agente (Claude Code o Copilot) con instrucciones ALDC debería:
1. Generar código AL más correcto (mayor pass rate en bug-fix)
2. Seguir mejores patrones (events, extensions, naming conventions)
3. Producir tests más robustos (mejor pass rate en test-generation)

### Diseño del experimento

```
┌─────────────────────────────────────────────────────────┐
│                    MISMO DATASET                        │
│                    MISMO MODELO                         │
│                    MISMO ENTORNO                        │
├──────────────────────┬──────────────────────────────────┤
│     SIN ALDC         │         CON ALDC                 │
│  (baseline)          │  (instructions + skills + agent) │
│                      │                                  │
│  Prompt genérico     │  AGENTS.md con routing ALDC      │
│  Sin skills          │  11 skills de dominio AL         │
│  Sin reglas          │  8 reglas de coding standards    │
│  Agente vanilla      │  --agent=al-developer            │
│                      │                                  │
│  → Métricas A        │  → Métricas B                    │
└──────────────────────┴──────────────────────────────────┘
                       │
                  COMPARAR A vs B
                  (pass rate, tokens, tiempo)
```

---

## Cómo se integró ALDC en BC-Bench

### Arquitectura de BC-Bench para instrucciones custom

BC-Bench ya tiene un mecanismo para inyectar configuraciones personalizadas. Todo se controla desde `src/bcbench/agent/shared/config.yaml`:

```yaml
# Habilitar/deshabilitar instrucciones custom
instructions:
  enabled: true    # Copia AGENTS.md → .claude/CLAUDE.md

# Habilitar/deshabilitar skills
skills:
  enabled: true    # Copia skills/ → .claude/skills/

# Habilitar/deshabilitar agentes custom
agents:
  enabled: true
  name: al-developer    # Se pasa como --agent=al-developer
```

### Flujo interno

Cuando BC-Bench ejecuta una evaluación con ALDC habilitado:

```
1. setup_instructions_from_config()
   └─ Copia TODO desde instructions/microsoft-BCApps/ → repo/.claude/
   └─ Renombra AGENTS.md → CLAUDE.md

2. setup_agent_skills()
   └─ Copia skills/ → repo/.claude/skills/

3. setup_custom_agent()
   └─ Copia agents/ → repo/.claude/agents/
   └─ Retorna "al-developer" como nombre del agente

4. Claude Code se ejecuta:
   claude --agent=al-developer --mcp-config=... --print "Fix the issue..."
```

### Estructura de archivos creada

Para cada repositorio del dataset (`microsoft-BCApps` y `microsoftInternal-NAV`):

```
src/bcbench/agent/shared/instructions/microsoft-BCApps/
├── AGENTS.md                          # Info del repo + instrucciones ALDC
│                                      # (se renombra a CLAUDE.md o copilot-instructions.md)
│
├── agents/                            # 8 agentes ALDC + 1 existente
│   ├── al-developer.md                # Implementation Specialist (el que usamos)
│   ├── al-architect.md                # Architecture & Design
│   ├── al-conductor.md                # TDD Orchestrator
│   ├── al-presales.md                 # Estimation
│   ├── al-implement-subagent.md       # Subagente TDD
│   ├── al-planning-subagent.md        # Subagente investigación
│   ├── al-review-subagent.md          # Subagente code review
│   ├── al-agent-builder.md            # BC Agent SDK builder
│   └── ALTest.agent.md                # (existente de BC-Bench)
│
├── skills/                            # 11 skills de dominio + 1 existente
│   ├── skill-api/SKILL.md
│   ├── skill-copilot/SKILL.md
│   ├── skill-debug/SKILL.md
│   ├── skill-estimation/SKILL.md
│   ├── skill-events/SKILL.md
│   ├── skill-migrate/SKILL.md
│   ├── skill-pages/SKILL.md
│   ├── skill-performance/SKILL.md
│   ├── skill-permissions/SKILL.md
│   ├── skill-testing/SKILL.md
│   ├── skill-translate/SKILL.md
│   └── al-test-generation/SKILL.md    # (existente de BC-Bench)
│
└── rules/                             # 8 reglas de coding standards
    ├── al-guidelines.md
    ├── al-code-style.md
    ├── al-naming-conventions.md
    ├── al-performance.md
    ├── al-error-handling.md
    ├── al-events.md
    ├── al-testing.md
    └── al-agent-toolkit.md
```

### Skills omitidos intencionalmente

ALDC tiene 25 skills en total. Solo se incluyeron los **11 skills de dominio** (conocimiento AL). Se omitieron:

- **10 workflow skills** (`al-build`, `al-spec-create`, etc.): Son para orquestación de procesos (crear specs, compilar, preparar PRs). No aportan a resolver bugs individuales.
- **4 skills de Agent SDK** (`skill-agent-toolkit`, etc.): Son para construir agentes de BC con el SDK, no para desarrollo AL general.

---

## Cómo ejecutar la evaluación

### Prerequisitos

| Componente | Propósito | Instalación |
|---|---|---|
| **Windows + Hyper-V** | Contenedor BC requiere Hyper-V | Activar en Windows Features |
| **Docker Desktop** | Runtime de contenedores | [docker.com](https://www.docker.com/products/docker-desktop/) |
| **PowerShell 7+** | Scripts de setup | `winget install Microsoft.PowerShell` |
| **Python 3.13+** | BC-Bench harness | Via [uv](https://docs.astral.sh/uv/) |
| **Node.js 24+** | Claude Code CLI | [nodejs.org](https://nodejs.org/) |
| **Claude Code** | Agente a evaluar | `npm install -g @anthropic-ai/claude-code` |
| **BcContainerHelper** | Módulo PowerShell para BC | `Install-Module BcContainerHelper` |

### Variables de entorno

```powershell
# Requeridas
$env:ANTHROPIC_API_KEY = "sk-ant-..."          # API key de Anthropic
$env:GITHUB_TOKEN = "ghp_..."                  # Para clonar microsoft/BCApps
$env:BC_CONTAINER_PASSWORD = "MiPassword123!"  # Password del contenedor BC

# Opcionales
$env:BC_CONTAINER_NAME = "bcbench"             # Nombre del contenedor (default: bcbench)
$env:BC_CONTAINER_USERNAME = "admin"           # Usuario del contenedor (default: admin)
$env:ADO_TOKEN = "..."                         # Solo si evalúas entries de microsoftInternal/NAV
```

### Opción 1: Script automatizado (recomendado)

```powershell
# Clonar BC-Bench
git clone https://github.com/javiarmesto/bc-bench
cd bc-bench

# Evaluar un entry específico con ALDC
.\scripts\Setup-ALDCEvaluation.ps1 -InstanceId "microsoft__BCApps-5633"

# Test rápido (solo 2 entries)
.\scripts\Setup-ALDCEvaluation.ps1 -TestRun

# Comparar ALDC vs baseline
.\scripts\Setup-ALDCEvaluation.ps1 -InstanceId "microsoft__BCApps-5633" -CompareBaseline

# Usar otro modelo
.\scripts\Setup-ALDCEvaluation.ps1 -TestRun -Model "claude-opus-4-6"

# Reusar infraestructura existente
.\scripts\Setup-ALDCEvaluation.ps1 -InstanceId "microsoft__BCApps-5633" `
    -SkipContainerSetup -SkipRepoClone -RepoPath "C:\testbed"
```

El script automatiza:
1. Validación de prerequisitos
2. Instalación de dependencias
3. Clonado del repositorio al commit correcto
4. Creación del contenedor BC
5. Ejecución de la evaluación
6. (Opcional) Comparación con baseline

### Opción 2: Paso a paso manual

```powershell
cd bc-bench

# 1. Instalar dependencias Python
uv sync --all-groups

# 2. Verificar que ALDC está habilitado en config
# src/bcbench/agent/shared/config.yaml debe tener:
#   instructions.enabled: true
#   skills.enabled: true
#   agents.enabled: true / name: al-developer

# 3. Crear contenedor BC (primera vez, ~20 min)
pwsh scripts/Setup-ContainerAndRepository.ps1 `
    -InstanceId "microsoft__BCApps-5633" `
    -ContainerName "bcbench" `
    -RepoPath "C:\testbed"

# 4. Ejecutar evaluación con ALDC
uv run bcbench evaluate claude "microsoft__BCApps-5633" `
    --model "claude-sonnet-4-6" `
    --category "bug-fix" `
    --repo-path "C:\testbed" `
    --output-dir "evaluation_results" `
    --container-name "bcbench" `
    --username "admin" `
    --password $env:BC_CONTAINER_PASSWORD `
    --al-mcp

# 5. Para comparar SIN ALDC: editar config.yaml
#    instructions.enabled: false
#    skills.enabled: false
#    agents.enabled: false
# Y repetir el paso 4 con --output-dir "baseline_results"

# 6. Agregar resultados
uv run bcbench result aggregate --input-dir evaluation_results
uv run bcbench result aggregate --input-dir baseline_results
```

### Opción 3: Solo generar parche (sin contenedor BC)

Si no tienes infraestructura BC pero quieres ver qué genera el agente:

```powershell
# Requiere: repo clonado + Claude Code instalado
uv run bcbench run claude "microsoft__BCApps-5633" `
    --category "bug-fix" `
    --repo-path "C:\BCApps" `
    --output-dir "patches" `
    --al-mcp
```

Esto ejecuta el agente y captura el parche generado, sin compilar ni ejecutar tests.

---

## Cómo alternar entre ALDC y baseline

El interruptor está en `src/bcbench/agent/shared/config.yaml`:

### Con ALDC (evaluar el framework)

```yaml
instructions:
  enabled: true
skills:
  enabled: true
agents:
  enabled: true
  name: al-developer
```

### Sin ALDC (baseline)

```yaml
instructions:
  enabled: false
skills:
  enabled: false
agents:
  enabled: false
  name: al-developer
```

El flag `--al-mcp` (AL MCP server) se mantiene igual en ambos casos para que la única variable sea ALDC.

---

## Qué esperamos observar

### Métricas a comparar

| Métrica | Baseline (sin ALDC) | Con ALDC | Significado |
|---|---|---|---|
| **Pass rate (bug-fix)** | X% | Y% | ¿ALDC ayuda a resolver más bugs? |
| **Pass rate (test-gen)** | X% | Y% | ¿ALDC genera mejores tests? |
| **Build errors** | N | M | ¿ALDC reduce errores de compilación? |
| **Avg. execution time** | Xs | Ys | ¿ALDC añade overhead significativo? |
| **Avg. tokens** | N | M | ¿Más contexto = más tokens? |
| **Empty diffs** | N | M | ¿ALDC reduce "no sé qué hacer"? |

### Hipótesis de resultados

- **Pass rate**: Esperamos mejora, especialmente en tareas que requieren patrones específicos de AL (events, permissions, test structure)
- **Build errors**: Esperamos reducción gracias a las reglas de naming, code-style y error-handling
- **Tokens**: Esperamos aumento (más contexto = más tokens), la pregunta es si el trade-off vale la pena
- **Tiempo**: Posible aumento marginal por el contexto adicional

---

## Limitaciones y trabajo pendiente

### No probado aún

Esta integración está diseñada pero **no ejecutada**. Los resultados son hipotéticos hasta que se ejecute en un entorno con:
- Contenedor de Business Central funcionando
- Repositorio BCApps clonado
- Claude Code con API key válida

### Limitaciones conocidas

1. **Contexto del agente**: ALDC añade ~22,000 líneas de instrucciones. Dependiendo del modelo, esto puede saturar el contexto o diluir la tarea principal.

2. **al-developer vs vanilla**: El agente `al-developer` de ALDC está diseñado para desarrollo interactivo (con builds, tests, tools de VS Code). En BC-Bench, el agente opera en modo no-interactivo (`--print`), sin acceso a herramientas de VS Code. Algunas instrucciones de ALDC pueden no aplicar.

3. **Skills evidencing**: ALDC requiere que los agentes declaren qué skills cargaron. Esto consume tokens sin beneficio directo para la resolución del bug.

4. **HITL gates**: ALDC incluye pausas para aprobación humana. En modo automatizado de BC-Bench, estas pausas no aplican.

5. **Workflow skills omitidos**: Los 10 workflow skills de ALDC (`al-build`, `al-spec-create`, etc.) no se incluyeron. Si el agente intenta invocarlos, no los encontrará.

### Próximos pasos

- [ ] Ejecutar evaluación con ALDC en entorno real
- [ ] Ejecutar baseline (sin ALDC) con el mismo dataset
- [ ] Comparar métricas y analizar diferencias
- [ ] Optimizar: ¿qué combinación de skills/rules da mejor resultado?
- [ ] Probar con diferentes modelos (Haiku, Sonnet, Opus)
- [ ] Evaluar con Copilot CLI además de Claude Code
- [ ] Publicar resultados en el leaderboard de BC-Bench

---

## Estructura del proyecto

```
BC-Bench/
├── scripts/
│   └── Setup-ALDCEvaluation.ps1          # Script de setup + evaluación
│
├── src/bcbench/agent/shared/
│   ├── config.yaml                        # Interruptor ALDC on/off
│   └── instructions/
│       ├── microsoft-BCApps/              # Instrucciones para BCApps
│       │   ├── AGENTS.md                  # Info repo + ALDC routing
│       │   ├── agents/                    # 8 agentes ALDC
│       │   ├── skills/                    # 11+1 skills
│       │   └── rules/                     # 8 reglas de coding
│       │
│       └── microsoftInternal-NAV/         # Instrucciones para NAV
│           ├── AGENTS.md                  # Info repo + ALDC routing
│           ├── agents/                    # 8 agentes ALDC
│           ├── skills/                    # 11+1 skills
│           ├── rules/                     # 8 reglas de coding
│           └── instructions/              # 3 instrucciones NAV-específicas
│
├── dataset/bcbench.jsonl                  # ~100 tareas de benchmark
└── ...
```

---

## Referencias

- **BC-Bench**: [Microsoft Learn](https://learn.microsoft.com/en-us/dynamics365/release-plan/2026wave1/smb/dynamics365-business-central/evaluate-al-coding-agents-bc-bench) · [GitHub](https://github.com/javiarmesto/bc-bench)
- **ALDC**: [GitHub](https://github.com/javiarmesto/ALDC-AL-Development-Collection) · [Sessionize](https://sessionize.com/s/javiarmesto/building-business-central-extensions-with-github-c/163676)
- **SWE-Bench** (inspiración): [GitHub](https://github.com/swe-bench/SWE-bench)
- **Artículo relacionado**: [azurecurve - BC-Bench 2026 Wave 1](https://www.azurecurve.co.uk/2026/03/new-functionality-in-microsoft-dynamics-365-business-central-2026-wave-1-evaluate-al-coding-agents-with-bc-bench/)
- **Video**: [YouTube](https://youtu.be/XGEDwzIZQj4)

---

> **Autor**: Generado con Claude Code (Opus 4.6) durante una sesión de diseño e integración.
> **Fecha**: Abril 2026
> **Estado**: Diseño completado. Pendiente de ejecución y validación.

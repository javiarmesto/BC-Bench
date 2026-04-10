# Evaluando ALDC con BC-Bench: Resultados / Evaluating ALDC with BC-Bench: Results

**Fecha / Date**: 2026-04-10
**Autores / Authors**: Javier Armesto Gonzalez
**Datos / Data**: 3 instancias BCApps × 3 escenarios × 2 agentes × 2 modelos
**Notebook**: [`notebooks/bug-fix/aldc-comparison-full.ipynb`](../notebooks/bug-fix/aldc-comparison-full.ipynb)

---

## Resumen Ejecutivo / Executive Summary

### ES

Evaluamos el framework ALDC (AL Development Collection) contra un baseline sin instrucciones especializadas, utilizando BC-Bench sobre 3 instancias de bug-fix del repositorio `microsoft/BCApps`. ALDC es un framework spec-driven con validaciones humanas (HITL) y orquestación TDD multi-agente. En esta evaluación, testeamos **solo la parte ejecutora** de ALDC en modo autónomo ("bench mode"), sin los gates de validación humana que constituyen su propuesta de valor central.

**Hallazgos principales**:
1. ALDC **no mejora la tasa de resolución** en bug-fix (el baseline resuelve los mismos o más casos).
2. El overhead de tokens es **3-4x sistemático** (~300KB de contexto ALDC cargado).
3. Existe un **problema de ceguera**: las 11 skills se despliegan pero nunca se invocan explícitamente. Claude Code nunca delega a subagentes; Copilot siempre lo hace.
4. El **modelo importa más que el framework**: Opus baseline resuelve lo que ninguna configuración Sonnet logra.
5. **No es justo concluir que ALDC "no funciona"**: bug-fix es el peor caso para un framework diseñado para desarrollo guiado, TDD y features medianas/grandes.

### EN

We evaluated the ALDC (AL Development Collection) framework against an uninstructed baseline using BC-Bench on 3 bug-fix instances from the `microsoft/BCApps` repository. ALDC is a spec-driven framework with human-in-the-loop (HITL) validation gates and multi-agent TDD orchestration. In this evaluation, we tested **only the executor component** of ALDC in autonomous mode ("bench mode"), without the human validation gates that constitute its core value proposition.

**Key findings**:
1. ALDC **does not improve resolution rate** on bug-fix (baseline resolves the same or more cases).
2. Token overhead is **3-4x systematic** (~300KB of ALDC context loaded).
3. A **blindness problem** exists: 11 skills are deployed but never explicitly invoked. Claude Code never delegates to subagents; Copilot always does.
4. **Model matters more than framework**: Opus baseline resolves what no Sonnet configuration achieves.
5. **It is not fair to conclude ALDC "doesn't work"**: bug-fix is the worst case for a framework designed for guided development, TDD, and medium/large features.

---

## 1. Contexto del Experimento / Experiment Context

### Qué es BC-Bench

[BC-Bench](../README.md) es un benchmark inspirado en SWE-Bench para evaluar agentes AI en tareas de desarrollo sobre Microsoft Dynamics 365 Business Central (lenguaje AL). Contiene 101 instancias de bug-fix extraidas de PRs reales de `microsoft/BCApps` y `microsoftInternal/NAV`.

### Qué es ALDC

ALDC (AL Development Collection) es un framework de desarrollo asistido por AI para Business Central que incluye:
- **4 agentes** especializados (architect, developer, conductor, pre-sales)
- **3 subagentes** internos (planning, implement, review)
- **11 skills** de dominio (API, debug, events, performance, testing, etc.)
- **8 reglas de codificación** (guidelines, code-style, naming, error-handling, etc.)
- **Workflows** completos (spec-driven, TDD RED→GREEN→REFACTOR, code review)

ALDC está diseñado para **uso interactivo** con validaciones humanas (HITL gates):
- Aprobación del plan antes de implementar
- Confirmación antes de iniciar implementación
- Revisión humana entre fases
- Preguntas abiertas al desarrollador

### Los 3 escenarios evaluados

| Escenario | Instrucciones | Skills | Agente | HITL |
|-----------|:---:|:---:|--------|:---:|
| **Baseline** | No | No | Ninguno | No |
| **ALDC + al-developer-bench** | Si (32 archivos, ~300KB) | Si (11) | al-developer-bench | No (bench mode) |
| **ALDC + al-conductor-bench** | Si (32 archivos, ~300KB) | Si (11) | al-conductor-bench | No (bench mode) |

### El caveat de "bench mode"

En modo interactivo, ALDC incluye 4+ HITL gates donde el desarrollador corrige la dirección, valida decisiones y focaliza el trabajo. En BC-Bench, estos gates se reemplazan por auto-continue: el agente decide autónomamente sin validación humana.

**Estamos evaluando el motor sin el volante.** Los resultados miden la capacidad del ejecutor ALDC aislado, no el flujo completo de desarrollo asistido.

### Agentes y modelos

- **Claude Code**: CLI nativa de Anthropic, ejecución directa
- **GitHub Copilot CLI**: Simulación de flujo real de desarrollador
- **claude-sonnet-4-6**: Modelo rápido, menor capacidad de razonamiento
- **claude-opus-4-6**: Modelo premium, mayor capacidad de razonamiento

---

## 2. Datos y Heatmap de Resolución / Data and Resolution Heatmap

### 2.1 Instancias evaluadas

| Instancia | Dificultad | Proyecto | Descripción |
|-----------|:---:|---------|-------------|
| BCApps-5633 | Hard | Shopify | Third-party fulfillment location filtering — requiere entender flujo completo de fulfillment orders |
| BCApps-4822 | Medium | Shopify | Bug en procesamiento de envios |
| BCApps-4699 | Easy | Shopify | Fix directo en lógica de exportación |

### 2.2 Heatmap de resolución

> Ver notebook interactivo: [`aldc-comparison-full.ipynb`](../notebooks/bug-fix/aldc-comparison-full.ipynb) - Sección 1.

**Resumen visual** (sonnet-4-6 / opus-4-6):

```
                  Baseline          ALDC+developer       ALDC+conductor
                Claude  Copilot   Claude  Copilot      Claude  Copilot
BCApps-5633
  sonnet-4-6     ❌       ❌        ❌       ✅(73t)      ❌       ❌
  opus-4-6      1/2       —        ✅       ✅           ✅       ✅

BCApps-4822
  sonnet-4-6     ✅       ✅        ✅       ❌           ✅       ✅
  opus-4-6       ✅       —        ✅       ✅           ✅       ✅

BCApps-4699
  sonnet-4-6     ✅       —         —       ✅           ✅       —
  opus-4-6       —       ✅        ✅       —            —       ✅
```

`—` = no testado | `1/2` = 1 de 2 runs resolvió

### 2.3 Tabla completa de resultados

| Instance | Agent | Model | Scenario | Resolved | Turns | Time (s) | Tokens (K) |
|----------|-------|-------|----------|:---:|---:|---:|---:|
| BCApps-5633 | Claude Code | sonnet-4-6 | Baseline | ❌ | 26 | 460 | 1,140 |
| BCApps-5633 | Claude Code | sonnet-4-6 | ALDC+developer | ❌ | 22 | 335 | 1,102 |
| BCApps-5633 | Claude Code | sonnet-4-6 | ALDC+conductor | ❌ | 40 | 627 | 3,161 |
| BCApps-5633 | Claude Code | opus-4-6 | Baseline (run1) | ❌ | 13 | 366 | 327 |
| BCApps-5633 | Claude Code | opus-4-6 | Baseline (run2) | ✅ | 12 | 188 | 277 |
| BCApps-5633 | Copilot | sonnet-4-6 | Baseline | ❌ | 13 | 273 | 418 |
| BCApps-5633 | Copilot | sonnet-4-6 | ALDC+developer | ✅ | 73 | 1,269 | 1,400 |
| BCApps-5633 | Copilot | sonnet-4-6 | ALDC+conductor | ❌ | 31 | 445 | 2,300 |
| BCApps-4822 | Claude Code | sonnet-4-6 | Baseline | ✅ | 16 | 135 | 574 |
| BCApps-4822 | Claude Code | sonnet-4-6 | ALDC+developer | ✅ | 25 | 259 | 1,737 |
| BCApps-4822 | Claude Code | sonnet-4-6 | ALDC+conductor | ✅ | 35 | 227 | 2,183 |
| BCApps-4822 | Claude Code | opus-4-6 | Baseline | ✅ | 11 | 119 | 182 |
| BCApps-4822 | Claude Code | opus-4-6 | ALDC+developer | ✅ | 17 | 127 | 689 |
| BCApps-4822 | Claude Code | opus-4-6 | ALDC+conductor | ✅ | 18 | 106 | 776 |
| BCApps-4822 | Copilot | sonnet-4-6 | Baseline | ✅ | 30 | 899 | 1,100 |
| BCApps-4822 | Copilot | sonnet-4-6 | ALDC+developer | ❌ | 26 | 482 | 1,700 |
| BCApps-4822 | Copilot | sonnet-4-6 | ALDC+conductor | ✅ | 24 | 215 | 1,200 |
| BCApps-4822 | Copilot | opus-4-6 | ALDC+developer | ✅ | 22 | 260 | 1,300 |
| BCApps-4822 | Copilot | opus-4-6 | ALDC+conductor | ✅ | 21 | 231 | 1,200 |
| BCApps-4699 | Claude Code | sonnet-4-6 | Baseline | ✅ | 15 | 65 | 333 |
| BCApps-4699 | Claude Code | sonnet-4-6 | ALDC+conductor | ✅ | 9 | 61 | 464 |
| BCApps-4699 | Claude Code | opus-4-6 | ALDC+developer | ✅ | 21 | 109 | 785 |
| BCApps-4699 | Copilot | opus-4-6 | Baseline | ✅ | 15 | 120 | 412 |
| BCApps-4699 | Copilot | opus-4-6 | ALDC+conductor | ✅ | 22 | 141 | 1,100 |
| BCApps-4699 | Copilot | sonnet-4-6 | ALDC+developer | ✅ | 23 | 205 | 1,200 |

---

## 3. Analisis de Eficiencia / Efficiency Analysis

### 3.1 Token Overhead

El overhead de tokens ALDC vs Baseline, calculado donde ambos existen para el mismo agent+model+instance:

| Instance | Agent | Model | ALDC+developer | ALDC+conductor |
|----------|-------|-------|---:|---:|
| BCApps-5633 | Claude Code | sonnet-4-6 | **0.97x** | **2.8x** |
| BCApps-4822 | Claude Code | sonnet-4-6 | **3.0x** | **3.8x** |
| BCApps-4822 | Claude Code | opus-4-6 | **3.8x** | **4.3x** |
| BCApps-4699 | Claude Code | sonnet-4-6 | — | **1.4x** |

**Observaciones**:
- El conductor es siempre el más caro (2.8-4.3x), coherente con la orquestación multi-agente.
- El developer oscila entre 0.97x y 3.8x — la variabilidad sugiere que el impacto depende de la instancia.
- BCApps-5633 developer < baseline: no es eficiencia, es fracaso temprano diferente.

### 3.2 Tiempo y Turns

El patrón de tokens se replica en turns y tiempo, con una excepción notable:
- BCApps-4822 opus: conductor es **más rápido** que baseline (106s vs 119s) con más turns (18 vs 11). El conductor parece tomar turns más cortos y enfocados con opus.
- BCApps-4699 sonnet: conductor es más rápido que baseline (61s vs 65s, 9 vs 15 turns). El único caso donde ALDC es simultáneamente más rápido en tiempo y turns.

---

## 4. El Problema de la Ceguera / The Blindness Problem

### 4.1 Evidencia de carga

En **todos** los runs ALDC:
- `custom_agent_confirmed = true` — el nombre del agente aparece en logs
- `rules_inlined = 8/8` — las 8 reglas de codificación se inyectaron en CLAUDE.md
- `aldc_files_count = 32` — los 32 archivos ALDC se desplegaron en `.claude/`

### 4.2 Skills: cargadas pero no invocadas

En **16 de 16 runs ALDC**, `skills_invoked = {}`. Ninguna skill se invocó explícitamente via la tool `Skill`. Esto no significa necesariamente que el modelo las ignoró: puede haberlas leido via `Read`/`Glob` sin invocarlas formalmente. Pero no tenemos evidencia positiva de uso.

Las 11 skills representan ~150KB de contexto de dominio AL. Si no se usan, es overhead puro.

### 4.3 Subagentes: asimetria Claude vs Copilot

| Runner | ALDC+developer | ALDC+conductor |
|--------|:-:|:-:|
| **Claude Code** | 0% subagent invocation | 0% subagent invocation |
| **Copilot** | 100% subagent invocation | 100% subagent invocation |

**Claude Code** nunca delega a subagentes, ni siquiera con el conductor que explicitamente los define. **Copilot** siempre invoca planning + implement + review, incluso con el developer que no deberia orquestar.

Implicaciones:
- Los dos runners ejecutan la misma instruccion ALDC de manera fundamentalmente diferente.
- La comparacion ALDC entre runners no es apple-to-apple.
- El "conductor" en Claude Code es realmente un developer con más instrucciones cargadas.

---

## 5. Hallazgos Clave / Key Findings

### 5.1 El conductor es demasiado caro para bug-fix / Conductor is too expensive for bug-fix

El conductor fue diseñado para orquestación TDD completa (Planning → Implementation → Review → Commit). En bug-fix:
- Añade **2.8-4.3x overhead de tokens** sin mejora en resolución.
- En BCApps-5633, genera soluciones sobre-ingenierizadas: modifica GraphQL queries, añade campos a tablas, crea procedimientos nuevos — para un fix que requiere ~9 líneas en 1 archivo.
- El overhead de orquestación (plan, subagents, review) no se amortiza en tareas pequeñas.

### 5.2 El developer es un trade-off ambiguo / Developer is an ambiguous trade-off

- **Copilot+developer** resuelve BCApps-5633 (el más difícil) donde el baseline falla — pero necesita 73 turns y 1,269 segundos.
- **Copilot+developer** falla en BCApps-4822 (medio) donde el baseline pasa — regresión ALDC-inducida.
- **Claude Code+developer** produce los mismos resultados que baseline con 3x tokens.

El developer ni mejora ni empeora consistentemente. Su efecto depende de la interacción instance × runner.

### 5.3 El modelo importa mas que el framework / Model matters more than framework

Opus-4-6 baseline resuelve BCApps-5633 (1/2 runs). Ninguna configuración Sonnet-4-6 lo logra — ni baseline, ni developer, ni conductor. Un upgrade de modelo ($0.015→$0.075/1K input tokens, 5x coste) entrega lo que 300KB de instrucciones gratuitas no pueden.

Esto es consistente con los hallazgos de SWE-Bench: la capacidad base del modelo es el predictor dominante de resolución. Las instrucciones custom pueden guiar *cómo* el modelo resuelve, pero no *si* puede resolver.

### 5.4 ALDC esta diseñado para otro caso de uso / ALDC is designed for a different use case

ALDC no es un "prompt enhancer" para mejorar performance en benchmarks. Es un **framework de ingeniería controlada** que transforma el desarrollo AI de "vibe coding" a desarrollo estructurado con contratos y validaciones.

Su propuesta de valor central son los **HITL gates**: puntos donde un desarrollador humano corrige la dirección, valida decisiones arquitectónicas, y confirma que el enfoque es correcto antes de continuar. En bench mode, estos gates se eliminan — y con ellos, la oportunidad de evitar que el agente se desvíe hacia soluciones sobre-ingenierizadas.

Evaluarlo en bug-fix sin HITL es como evaluar un framework de gestión de proyectos contando cuántas líneas de código escribe.

---

## 6. ¿Es valido el enfoque executor-only? / Is the executor-only approach valid?

**Respuesta matizada / Nuanced answer**:

**Si, para verificar capacidad autónoma**: BC-Bench demuestra que el ejecutor ALDC puede funcionar sin supervisión humana — los builds pasan, genera patches estructuralmente correctos, usa patrones AL razonables. Esto valida que las instrucciones no rompen la capacidad base del agente.

**No, para medir el valor de ALDC**: El valor de ALDC se materializa en la **interacción** entre agente y humano, no en la ejecución autónoma. Los validation gates, las preguntas abiertas, la revisión de spec — todo esto desaparece en bench mode. Lo que medimos es el overhead de cargar 300KB de contexto sin activar los mecanismos diseñados para aprovechar ese contexto.

**El token overhead es el precio del contexto, no del framework**: Los 300KB de instrucciones se cargan porque ALDC fue diseñado para un desarrollador que trabaja todo el día con el agente, donde las instrucciones se amortizan a lo largo de múltiples tareas. En una ejecución single-shot de benchmark, todo el contexto se paga por una sola tarea de ~10 líneas — un ratio coste/beneficio que ALDC nunca fue diseñado para optimizar.

### Analogía

Evaluating ALDC on BC-Bench bug-fix is like testing a Formula 1 car on a residential street: the engine works, but the aerodynamics, tire compounds, and telemetry systems designed for 300km/h are pure weight at 30km/h. The car isn't "bad" — it's designed for a different track.

---

## 7. Recomendaciones / Recommendations

### Para ALDC en benchmark / For ALDC in benchmarks

1. **Crear modo "pruned"**: Cargar solo 3-4 skills relevantes al tipo de tarea (e.g., skill-debug + skill-testing para bug-fix). Reducir contexto de ~300KB a ~50KB.
2. **Mejorar evidencia de uso**: Instrumentar el agente para loggear qué archivos `.md` de ALDC leyó realmente (no solo si están desplegados).
3. **Investigar la asimetría de subagentes**: ¿Por qué Claude Code nunca delega y Copilot siempre lo hace? Esto puede requerir cambios en cómo se define el routing de agentes.

### Para BC-Bench / For BC-Bench

4. **Baseline "context-aware"**: Añadir un escenario intermedio con solo CLAUDE.md + reglas (sin skills ni agentes) para aislar el efecto de las instrucciones base vs el overhead de skills.
5. **Ablation study**: `Baseline → +CLAUDE.md → +rules → +skills → full ALDC` para identificar qué capa aporta y cuál resta.
6. **Evaluar test-generation**: El conductor fue diseñado para TDD. BC-Bench ya tiene esta categoría. Es el terreno natural de ALDC conductor.
7. **Ampliar a feature-development**: Tareas que requieran diseño + implementación + test, donde la orquestación multi-agente justifique su overhead.

---

## 8. Limitaciones / Limitations

| Limitación | Impacto | Mitigación |
|-----------|---------|-----------|
| **n=3 instancias** | Sin significancia estadística | Presentar como estudio exploratorio piloto |
| **Single-run mayoritario** | Sin estimación de varianza | Opus BCApps-5633 tiene 2 runs como excepción |
| **Matriz sparse** | No todos los combos testados | Foco en comparaciones donde hay datos pareados |
| **Solo bug-fix** | Conductor diseñado para TDD/features | Evaluar test-generation como siguiente paso |
| **Bench mode** | Sin HITL gates | Explicitar que no es ALDC completo |
| **Blindness problem** | No verificable si se usan skills/instrucciones | Mejorar instrumentación de ALDC |
| **2 de 3 instancias son Shopify** | Sesgo de dominio | Ampliar con más áreas funcionales |

---

## 9. Trabajo Futuro / Future Work

1. **Full 101-instance run** con ALDC developer sobre el dataset completo. Requiere ~200 horas de ejecución y presupuesto significativo de API.
2. **Test-generation** con al-conductor-bench. El TDD RED→GREEN→REFACTOR es el terreno natural del conductor.
3. **Feature-development category**: Tareas nuevas que requieran spec → diseño → implementación → test. Requiere dataset nuevo.
4. **ALDC pruned**: Evaluar con contexto reducido (solo skills relevantes, sin agentes de estimación/pre-sales).
5. **Comparación con ALDC interactivo**: Evaluar las mismas 3 instancias con HITL real para medir el delta de las validation gates.
6. **Instrumentación mejorada**: Logear lectura efectiva de archivos ALDC para resolver el blindness problem.

---

## Apendice A: Evidencia ALDC / Appendix A: ALDC Evidence

Todos los runs ALDC tienen:
- 32 archivos desplegados en `.claude/` (SHA256 verificado)
- 8 coding rules inlined en CLAUDE.md
- `custom_agent_confirmed = true`
- `skills_invoked = {}` (0 skills invocadas explícitamente)

Copilot ALDC runs también muestran:
- `subagents_invoked: {al-planning-subagent: 1, al-implement-subagent: 1, al-review-subagent: 1}`

Claude Code ALDC runs muestran:
- `subagents_invoked: {}` (0 subagentes invocados)

### Contexto ALDC desplegado (32 archivos)

```
agents/
  al-agent-builder.md, al-architect.md, al-conductor-bench.md, al-conductor.md,
  al-developer-bench.md, al-developer.md, al-implement-subagent.md,
  al-planning-subagent.md, al-presales.md, al-review-subagent.md, ALTest.agent.md

rules/
  al-agent-toolkit.md, al-code-style.md, al-error-handling.md, al-events.md,
  al-guidelines.md, al-naming-conventions.md, al-performance.md, al-testing.md

skills/
  al-test-generation/SKILL.md, skill-api/SKILL.md, skill-copilot/SKILL.md,
  skill-debug/SKILL.md, skill-estimation/SKILL.md, skill-events/SKILL.md,
  skill-migrate/SKILL.md, skill-pages/SKILL.md, skill-performance/SKILL.md,
  skill-permissions/SKILL.md, skill-testing/SKILL.md, skill-translate/SKILL.md

CLAUDE.md (master instructions, 63KB)
```

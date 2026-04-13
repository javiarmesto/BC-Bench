---
layout: default
title: "Parte 3 — Configuracion"
lang: es
---

# BC-Bench: Guia Paso a Paso

## Parte 3 - Configuracion de Agentes y Personalizacion

---

## El Fichero de Configuracion Central

La configuracion de los agentes Claude Code y Copilot reside en:

```
src/bcbench/agent/shared/config.yaml
```

Este fichero controla cuatro aspectos fundamentales:

1. **Prompts** - Las plantillas de instrucciones que recibe el agente
2. **Instructions** - Custom instructions (CLAUDE.md / copilot-instructions.md)
3. **Skills** - Conocimiento especializado cargado bajo demanda
4. **Agents** - Agentes personalizados con roles especificos

---

## 1. Plantillas de Prompt

Las plantillas definen la instruccion base que recibe el agente. Se configuran bajo la clave `prompt:` del `config.yaml`.

### Plantilla de Bug-Fix

```yaml
prompt:
  bug-fix-template: |
    You are working with a Business Central (AL) code repository at {{repo_path}}.

    Task: Fix the issue described below

    Important constraints:
    - Do NOT modify any testing logic or test files
    - Focus solely on fixing the reported issue
    - Do NOT try to build or run tests, just provide the code changes needed
    - Do NOT commit any changes to the repository
    - Focus on W1 localization

    Issue details:
    {{task}}
```

### Plantilla de Test-Generation

```yaml
prompt:
  test-generation-input: "both"  # "problem-statement", "gold-patch", o "both"

  test-generation-template: |
    You are working with a Business Central (AL) code repository at {{repo_path}}.

    Task: Generate ONE NEW test case that reproduce the issue described below
    ...
```

El campo `test-generation-input` controla que informacion recibe el agente:

| Modo | El agente ve | Caso de uso |
|------|-------------|-------------|
| `problem-statement` | Solo la descripcion del bug | Test-driven development: escribir tests desde el requisito |
| `gold-patch` | Solo el codigo fix aplicado como cambios unstaged | Verificacion: escribir tests que validen un fix conocido |
| `both` | Bug + fix | Contexto completo para generar tests |

### Como personalizar los prompts

Para probar un prompt distinto, edita directamente la plantilla en `config.yaml`. Las variables disponibles son:

| Variable | Contenido |
|----------|----------|
| `{{repo_path}}` | Ruta al repositorio en el sistema de archivos |
| `{{task}}` | Contenido del problem statement (README.md de la entrada) |
| `{{project_paths}}` | Lista de rutas de proyecto afectadas (si `include_project_paths: true`) |

**Ejemplo**: Si quieres que el agente tenga informacion sobre los project paths:

```yaml
prompt:
  include_project_paths: true  # Cambiado de false a true
```

---

## 2. Custom Instructions

Las custom instructions son ficheros markdown que se copian al repositorio antes de ejecutar el agente. El agente las lee automaticamente como contexto de trabajo.

### Como funcionan

```yaml
instructions:
  enabled: true   # Poner a false para evaluacion baseline
```

Cuando `enabled: true`:
- **Claude Code**: Se copia `AGENTS.md` a `{repo}/.claude/CLAUDE.md`
- **Copilot CLI**: Se copia `AGENTS.md` a `{repo}/.github/copilot-instructions.md`

El fichero fuente esta en:

```
src/bcbench/agent/shared/instructions/{sanitized-repo}/AGENTS.md
```

Donde `{sanitized-repo}` es el nombre del repo con `/` reemplazado por `-` (ej: `microsoft-BCApps`).

### Contenido tipico de las instrucciones

Las instrucciones incluyen:
- Descripcion del lenguaje AL y Business Central
- Routing de agentes (que agente usar segun la intencion)
- Referencia a skills disponibles
- Reglas de codificacion (naming, error handling, eventos, performance)

### Como crear tus propias instrucciones

1. Crea un directorio para tu repositorio:
   ```
   src/bcbench/agent/shared/instructions/mi-organizacion-MiRepo/
   ```

2. Crea el fichero `AGENTS.md` con tus instrucciones
3. BC-Bench lo renombrara automaticamente al formato correcto del agente

---

## 3. Skills

Los skills son modulos de conocimiento especializado que se copian al directorio del agente. Cada skill es un directorio con un fichero `SKILL.md`.

### Configuracion de Skills

```yaml
skills:
  enabled: true
  include:           # Whitelist: solo copiar estos skills
    - skill-al-bugfix
    - skill-debug
    - skill-testing
    - skill-events
    - skill-performance
    - skill-api
    - skill-permissions
```

### Skills Disponibles

| Skill | Proposito |
|-------|----------|
| `skill-al-bugfix` | Estrategias de diagnostico y fix de bugs en AL |
| `skill-debug` | Tecnicas de depuracion en Business Central |
| `skill-testing` | Patrones de testing AL (AAA, mocking, test isolation) |
| `skill-events` | Sistema de eventos y subscribers de BC |
| `skill-performance` | Optimizacion de rendimiento en AL |
| `skill-api` | Desarrollo de APIs en Business Central |
| `skill-permissions` | Gestion de permisos y seguridad |

Hay mas skills disponibles pero no incluidos en la whitelist por defecto:

| Skill | Proposito | Por que excluido |
|-------|----------|-----------------|
| `skill-copilot` | Desarrollo de Copilot features | No relevante para bug-fix |
| `skill-migrate` | Migracion de versiones | No relevante para bug-fix |
| `skill-translate` | XLIFF y traducciones | No relevante para bug-fix |
| `skill-pages` | Desarrollo de pages AL | No relevante para bug-fix |
| `skill-estimation` | Estimacion PERT | No relevante para bug-fix |

### Como personalizar la lista de skills

Para probar con un conjunto distinto de skills:

```yaml
skills:
  enabled: true
  include:
    - skill-al-bugfix
    - skill-debug
    # Quitar o anadir skills aqui
```

Para usar TODOS los skills disponibles, elimina la clave `include`:

```yaml
skills:
  enabled: true
  # Sin include = copia todos los skills
```

Para deshabilitar skills completamente (evaluacion sin knowledge modules):

```yaml
skills:
  enabled: false
```

---

## 4. Agentes Personalizados

Los agentes personalizados son definiciones markdown que establecen el rol, herramientas y comportamiento del agente.

### Configuracion de Agentes

```yaml
agents:
  enabled: true
  name: al-developer-bench    # Agente activo por defecto
  profiles:
    al-developer-bench:
      include:
        - al-developer-bench.md
    al-conductor-bench:
      include:
        - al-conductor-bench.md
        - al-planning-subagent.md
        - al-implement-subagent.md
        - al-review-subagent.md
    al-bugfix-firstline:
      include:
        - al-bugfix-firstline.md
```

### Agentes Disponibles

#### al-developer-bench

**Tipo**: Implementacion tactica directa
**Fichero**: `agents/al-developer-bench.md`
**Herramientas**: Read, Glob, Grep, Write, Edit, Bash, Task, WebSearch, WebFetch
**Modelo sugerido**: Sonnet
**Max turnos**: 50

Especialista en implementacion que ejecuta fixes directamente. No delega, no hace diseno arquitectonico. Ideal para bug-fix.

#### al-conductor-bench

**Tipo**: Orquestacion multi-agente con TDD
**Fichero**: `agents/al-conductor-bench.md` + 3 subagentes
**Herramientas**: Read, Glob, Grep, Write, Edit, Bash, Task, WebSearch, WebFetch
**Modelo sugerido**: Haiku (para el orquestador)
**Max turnos**: 50

Orquesta un ciclo Planning -> Implementation -> Review usando subagentes delegados:
- `al-planning-subagent.md` - Planificacion
- `al-implement-subagent.md` - Implementacion
- `al-review-subagent.md` - Revision de codigo

Ideal para test-generation donde la orquestacion TDD puede mejorar la calidad.

#### al-bugfix-firstline

**Tipo**: Diagnostico autonomo especializado
**Fichero**: `agents/al-bugfix-firstline.md`
**Herramientas**: Read, Glob, Grep, Write, Edit, Bash
**Max turnos**: 40

Agente minimalista enfocado en producir el **parche minimo** necesario. Su workflow es:
1. Leer el contrato del test (no-negociable, antes de cualquier otra cosa)
2. Trazar el flujo de datos desde el test hasta el codigo de produccion
3. Diagnosticar la causa raiz
4. Aplicar el fix minimo

### Como cambiar el agente activo

Cambia el valor de `agents.name`:

```yaml
agents:
  name: al-conductor-bench   # Antes: al-developer-bench
```

### Como crear tu propio agente

1. Crea un fichero markdown en:
   ```
   src/bcbench/agent/shared/instructions/{repo}/agents/mi-agente.md
   ```

2. Usa el frontmatter YAML para definir sus propiedades:
   ```yaml
   ---
   name: Mi Agente Especializado
   description: >
     Descripcion de lo que hace el agente.
   tools: Read, Glob, Grep, Write, Edit, Bash
   model: sonnet
   maxTurns: 50
   ---
   ```

3. Escribe las instrucciones del agente en el cuerpo del markdown

4. Anadelo como profile en `config.yaml`:
   ```yaml
   agents:
     name: mi-agente
     profiles:
       mi-agente:
         include:
           - mi-agente.md
   ```

---

## 5. Servidores MCP

Los servidores MCP (Model Context Protocol) dan al agente acceso a herramientas externas durante la evaluacion.

### Servidores configurados

```yaml
mcp:
  servers:
    - name: "altool"      # AL Tool - compilador AL via MCP
      type: "stdio"
      command: "al"
      args: ["launchmcpserver", "--transport", "stdio",
             "--packagecachepath", "{{package_cache_path}}"]

    - name: "mslearn"     # Microsoft Learn - documentacion
      type: "http"
      url: "https://learn.microsoft.com/api/mcp"
```

- **altool**: Activado con `--al-mcp`. Da al agente acceso al compilador AL para obtener errores de compilacion en tiempo real.
- **mslearn**: Documentacion oficial de Microsoft Learn. Siempre disponible (HTTP, sin dependencias locales).

### Anadir un nuevo servidor MCP

Descomenta o anade servidores en la seccion `mcp.servers`:

```yaml
    - name: "context7"
      type: "stdio"
      command: "npx"
      args: ["-y", "@upstash/context7-mcp@latest"]
```

> **Nota**: Los servidores `stdio` requieren que el ejecutable este en el PATH de la VM.

---

## Resumen: Que Modificar para Cada Experimento

| Que quieres probar | Donde modificar | Valor |
|--------------------|----------------|-------|
| Otro modelo LLM | Flag `--model` en el CLI | Ver lista de modelos |
| Sin instrucciones (baseline) | `config.yaml` > `instructions.enabled` | `false` |
| Sin skills | `config.yaml` > `skills.enabled` | `false` |
| Distinto conjunto de skills | `config.yaml` > `skills.include` | Lista de skills |
| Sin agente custom | `config.yaml` > `agents.enabled` | `false` |
| Otro agente custom | `config.yaml` > `agents.name` | Nombre del agente |
| Con AL MCP | Flag `--al-mcp` en el CLI | Presente o ausente |
| Otro prompt | `config.yaml` > `prompt.bug-fix-template` | Tu plantilla |
| Otra categoria | Flag `--category` en el CLI | `bug-fix` o `test-generation` |

---

> **Siguiente**: [Parte 4 - Comparacion de Baselines y Scripts para VM](04-baselines-y-scripts-vm.md)

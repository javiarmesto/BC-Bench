---
layout: default
title: "Parte 4 — Baselines y VM"
lang: es
---

# BC-Bench: Guia Paso a Paso

## Parte 4 - Comparacion de Baselines y Scripts para VM

---

## Preparando una VM para Evaluacion

Las evaluaciones completas (con build + tests) requieren un **Windows Server con Docker/Hyper-V** para ejecutar contenedores Business Central. BC-Bench incluye scripts para automatizar completamente el setup de la VM.

### Script de Setup en Dos Fases

#### Fase 1: Instalar features de Windows

```powershell
# Ejecutar como administrador en la VM
.\scripts\Setup-VM-Phase1.ps1
```

Que hace:
1. Instala Hyper-V y la feature de Containers
2. Desactiva Windows Defender real-time (mejora velocidad de compilacion BC)
3. Anade exclusiones en Defender para `C:\bcbench`, `C:\ProgramData\BcContainerHelper`
4. **Reinicia la maquina automaticamente**

#### Fase 2: Instalar software (tras reboot)

```powershell
.\scripts\Setup-VM-Phase2.ps1 `
  -AnthropicApiKey "sk-ant-..." `
  -GitHubToken "ghp_..." `
  -ContainerPassword "BcBench2026!"
```

Que instala (14 pasos con verificacion):
1. Verifica Hyper-V
2. Docker
3. PowerShell 7 (v7.5.1)
4. Git (v2.47.1)
5. uv + Python 3.13
6. Node.js (v22.15.0)
7. Claude Code (`npm install -g @anthropic-ai/claude-code`)
8. GitHub Copilot CLI
9. BcContainerHelper (modulo PowerShell)
10. AL Tool (dotnet tool, v17.0.33.55542)
11. Variables de entorno (ANTHROPIC_API_KEY, GITHUB_TOKEN, BC_CONTAINER_*)
12. Clona BC-Bench a `C:\bcbench`
13. `uv sync --all-groups` (dependencias Python)
14. Verificacion completa de todos los componentes

---

## Setup del Contenedor BC y Repositorio

Una vez la VM esta preparada, necesitas crear el contenedor BC y clonar el repositorio de evaluacion.

### Script de setup de contenedor

```powershell
.\scripts\Setup-ContainerAndRepository.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -ContainerName "bcbench" `
  -Username "admin"
```

Que hace:
1. Lee la entrada del dataset para obtener la version BC y el commit
2. Clona el repositorio en la ruta especificada (o `$env:GITHUB_WORKSPACE\testbed`)
3. Hace checkout del `base_commit` correcto
4. Descarga el artifact BC para la version requerida
5. Crea el contenedor Docker con `New-BCContainerSync`
6. Crea la carpeta del compilador
7. Inicializa el contenedor para desarrollo

> **Nota**: El contenedor se reutiliza entre evaluaciones que compartan la misma `environment_setup_version`. Solo se recrea cuando cambia la version de BC.

---

## Lanzando Evaluaciones Comparativas

### Script Principal: Setup-ALDCEvaluation.ps1

Este es el script principal para lanzar evaluaciones. Soporta multiples modos de operacion.

#### Evaluacion simple (un escenario)

```powershell
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Agent claude `
  -Model claude-sonnet-4-6 `
  -Category bug-fix
```

#### Evaluacion con escenario especifico

```powershell
# Solo baseline (sin instrucciones personalizadas)
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Scenario baseline

# Solo con agente developer
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Scenario aldc-developer

# Solo con agente conductor (TDD)
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Scenario aldc-conductor

# Solo con agente bugfix firstline
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Scenario aldc-bugfix
```

#### Comparacion baseline vs configuracion personalizada

```powershell
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -CompareBaseline
```

Ejecuta dos rondas: primero baseline (sin configuracion personalizada), luego con la configuracion activa en `config.yaml`.

#### Comparacion completa (3 escenarios)

```powershell
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -CompareAll `
  -PauseBetweenScenarios 180
```

Ejecuta tres rondas: baseline, developer, conductor. El parametro `-PauseBetweenScenarios` (en segundos) permite esperar entre ejecuciones para evitar errores de API por sobrecarga.

#### Parametros de referencia

| Parametro | Valores | Default |
|-----------|---------|---------|
| `-InstanceId` | ID del dataset | (todos si se omite) |
| `-Agent` | `claude`, `copilot` | `claude` |
| `-Model` | Ver lista de modelos | `claude-sonnet-4-6` |
| `-Category` | `bug-fix`, `test-generation` | `bug-fix` |
| `-Scenario` | `baseline`, `aldc-developer`, `aldc-conductor`, `aldc-bugfix` | (ninguno) |
| `-CompareBaseline` | Switch | `$false` |
| `-CompareAll` | Switch | `$false` |
| `-AlMcp` | Switch | `$true` |
| `-SkipContainerSetup` | Switch | `$false` |
| `-SkipRepoClone` | Switch | `$false` |
| `-TestRun` | Switch (solo 2 entradas) | `$false` |
| `-PauseBetweenScenarios` | Segundos | `0` |

---

## Comparacion Completa Multi-Agente: Run-FullComparison.ps1

Este script ejecuta **todos los escenarios** para **ambos agentes** (Claude + Copilot), recopila resultados, genera un informe y lo pushea al repositorio.

### Que escenarios ejecuta

El script define 8 escenarios (4 por agente):

| # | Agente | Escenario | Directorio de salida |
|---|--------|-----------|---------------------|
| 1 | Claude Code | baseline | `eval_claude_baseline_{model}` |
| 2 | Claude Code | developer | `eval_claude_aldc_developer_{model}` |
| 3 | Claude Code | conductor | `eval_claude_aldc_conductor_{model}` |
| 4 | Claude Code | bugfix | `eval_claude_aldc_bugfix_{model}` |
| 5 | Copilot | baseline | `eval_copilot_baseline_{model}` |
| 6 | Copilot | developer | `eval_copilot_aldc_developer_{model}` |
| 7 | Copilot | conductor | `eval_copilot_aldc_conductor_{model}` |
| 8 | Copilot | bugfix | `eval_copilot_aldc_bugfix_{model}` |

### Uso basico

```powershell
.\scripts\Run-FullComparison.ps1 `
  -InstanceIds "microsoft__BCApps-4822"
```

### Con multiples instancias

```powershell
.\scripts\Run-FullComparison.ps1 `
  -InstanceIds @("microsoft__BCApps-4822", "microsoft__BCApps-4699", "microsoft__BCApps-4766")
```

### Con modelo Opus

```powershell
.\scripts\Run-FullComparison.ps1 `
  -LlmFamily opus `
  -InstanceIds "microsoft__BCApps-4822"
```

El parametro `-LlmFamily` deriva automaticamente los IDs de modelo:
- Claude Code: `claude-{family}-4-6` (ej: `claude-opus-4-6`)
- Copilot: `claude-{family}-4.6` (ej: `claude-opus-4.6`)

### Ejemplo completo para produccion

```powershell
# Primero actualizar scripts
git -C C:\bcbench pull origin main

# Ejecutar comparacion completa con auto-shutdown
.\scripts\Run-FullComparison.ps1 `
  -InstanceIds @("microsoft__BCApps-4822") `
  -LlmFamily sonnet `
  -OnlyMissing `
  -EmailTo "tu-email@gmail.com" `
  -AutoShutdown
```

Parametros clave:
- `-OnlyMissing`: Salta escenarios que ya tienen resultados (para reanudar ejecuciones fallidas)
- `-EmailTo`: Envia resumen por email al terminar (requiere `$env:GMAIL_APP_PASSWORD`)
- `-AutoShutdown`: Apaga la VM tras completar (ahorra costes en cloud)
- `-SkipClaude` / `-SkipCopilot`: Ejecutar solo un agente
- `-PauseBetweenScenarios`: Segundos de espera entre escenarios (default: 30)

### Que hace al terminar

1. **Recopila resultados** de todos los directorios de salida
2. **Genera un informe markdown** con tabla comparativa
3. **Hace git push** de los resultados al branch configurado
4. **Envia email** con resumen (si configurado)
5. **Apaga la VM** (si `-AutoShutdown`)

Ejemplo de informe generado:

```markdown
# Evaluation Report: BCApps-4822

**Date:** 2026-04-13
**Model:** claude-sonnet-4-6 (Claude) / claude-sonnet-4.6 (Copilot)
**Total time:** ~180 minutes

## Results

| Agent | Scenario | Resolved | Build | Turns | Time | Tokens (K) |
|-------|----------|:--------:|:-----:|------:|-----:|-----------:|
| Claude Code | Baseline | X | V | 15 | 180s | 450K |
| Claude Code | Developer | V | V | 12 | 145s | 380K |
| Claude Code | Conductor | V | V | 18 | 210s | 520K |
| Copilot | Baseline | X | V | 20 | 195s | 470K |
| Copilot | Developer | V | V | 14 | 155s | 400K |
```

---

## Ejemplos Listos para Usar

### Ejemplo 1: Evaluar un bug con Claude Code baseline vs configuracion personalizada

```powershell
# Paso 1: Asegurarse de que el contenedor existe
.\scripts\Setup-ContainerAndRepository.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -RepoPath "C:\bcbench\testbed"

# Paso 2: Ejecutar baseline
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Scenario baseline `
  -Agent claude `
  -Model claude-sonnet-4-6 `
  -RepoPath "C:\bcbench\testbed" `
  -OutputDir "C:\bcbench\eval_baseline"

# Paso 3: Ejecutar con configuracion personalizada (reusar contenedor)
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Scenario aldc-developer `
  -Agent claude `
  -Model claude-sonnet-4-6 `
  -SkipContainerSetup `
  -SkipRepoClone `
  -RepoPath "C:\bcbench\testbed" `
  -OutputDir "C:\bcbench\eval_developer"
```

### Ejemplo 2: Evaluar test-generation con el agente conductor

```powershell
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Category test-generation `
  -Scenario aldc-conductor `
  -Agent claude `
  -Model claude-opus-4-6
```

### Ejemplo 3: Evaluar multiples instancias con Copilot

```powershell
.\scripts\Run-FullComparison.ps1 `
  -InstanceIds @(
    "microsoft__BCApps-4822",
    "microsoft__BCApps-4699",
    "microsoft__BCApps-4766"
  ) `
  -SkipClaude `
  -LlmFamily sonnet `
  -Category bug-fix `
  -OnlyMissing
```

### Ejemplo 4: Ejecutar escenarios manualmente con pausas entre ellos

Util cuando la API devuelve errores de sobrecarga (`overloaded_error`):

```powershell
# Escenario 1: Baseline
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Scenario baseline `
  -RepoPath "C:\bcbench\testbed"

# Esperar 5 minutos
Start-Sleep -Seconds 300

# Escenario 2: Developer
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Scenario aldc-developer `
  -SkipContainerSetup -SkipRepoClone `
  -RepoPath "C:\bcbench\testbed"

# Esperar 5 minutos
Start-Sleep -Seconds 300

# Escenario 3: Conductor
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Scenario aldc-conductor `
  -SkipContainerSetup -SkipRepoClone `
  -RepoPath "C:\bcbench\testbed"
```

---

> **Siguiente**: [Parte 5 - Obtencion, Analisis y Documentacion de Resultados](05-resultados-y-analisis.md)

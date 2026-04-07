# Plan: Evaluación de ALDC con BC-Bench — Azure Cloud Setup

## Contexto

Se ha integrado ALDC (AL Development Collection) en BC-Bench para medir el impacto de instrucciones estructuradas sobre agentes de IA en tareas reales de Business Central. Todo está en el branch `claude/explain-repo-usage-2rL3g`. El usuario no tiene infraestructura — se monta todo desde cero en Azure. Categoría inicial: **bug-fix**.

---

## Fase 0: Crear VM en Azure (~15 min)

### Especificaciones de la VM

| Parámetro | Valor |
|---|---|
| **VM Size** | **Standard_D8s_v3** (8 vCPUs, 32 GB RAM) |
| **Imagen** | Windows Server 2022 Datacenter |
| **Tipo de seguridad** | **Standard** (NO "Trusted Launch" — rompe nested virtualization) |
| **Disco OS** | 256 GB Premium SSD |
| **Región** | La más cercana a tu ubicación |
| **Coste estimado** | ~$280/mes (pay-as-you-go), ~$100/mes con reserva |

> **Importante**: Las VM serie Dv3/Dsv3 y Ev3/Esv3 soportan nested virtualization (Hyper-V dentro de Azure). Las B-series NO lo soportan. El tipo de seguridad DEBE ser "Standard".

### Crear la VM (Azure Portal o CLI)

```powershell
# Opción: Azure CLI (desde cualquier terminal con az instalado)
az group create --name rg-bcbench --location westeurope

az vm create `
    --resource-group rg-bcbench `
    --name vm-bcbench `
    --image MicrosoftWindowsServer:WindowsServer:2022-datacenter-g2:latest `
    --size Standard_D8s_v3 `
    --security-type Standard `
    --admin-username azureuser `
    --admin-password "TuPasswordSegura123!" `
    --os-disk-size-gb 256 `
    --public-ip-sku Standard

# Abrir RDP (puerto 3389)
az vm open-port --resource-group rg-bcbench --name vm-bcbench --port 3389
```

### Conectar por RDP
```
mstsc /v:<IP_PUBLICA_DE_LA_VM>
```

> **Tip de coste**: Apaga la VM cuando no la uses (`az vm deallocate`). Solo pagas cuando está encendida. El disco sigue cobrando (~$20/mes para 256 GB Premium SSD).

---

## Fase 1: Configurar la VM (~30-40 min)

*Todos estos comandos se ejecutan dentro de la VM Azure vía RDP.*

### 1.1 Activar Hyper-V y Contenedores
```powershell
# En PowerShell como Administrador
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart
# La VM se reiniciará — reconectar RDP después
```

Tras reinicio:
```powershell
Install-WindowsFeature -Name Containers
```

### 1.2 Instalar Docker (versión empresarial, no Desktop)
```powershell
# Docker EE viene preinstalado en Windows Server 2022 con Containers feature
# Si no está, instalar:
Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
Install-Package -Name docker -ProviderName DockerMsftProvider -Force
Restart-Service docker

# Verificar
docker info
```

### 1.3 Instalar PowerShell 7+
```powershell
# Windows Server 2022 incluye PowerShell 5.1. Instalar 7:
winget install Microsoft.PowerShell
# O si winget no está disponible:
Invoke-WebRequest -Uri "https://github.com/PowerShell/PowerShell/releases/download/v7.5.1/PowerShell-7.5.1-win-x64.msi" -OutFile "$env:TEMP\pwsh.msi"
Start-Process msiexec.exe -ArgumentList "/i $env:TEMP\pwsh.msi /quiet" -Wait

# Abrir nueva sesión con pwsh
pwsh
```

### 1.4 Instalar Git
```powershell
winget install Git.Git
# O:
Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/latest/download/Git-2.47.1-64-bit.exe" -OutFile "$env:TEMP\git.exe"
Start-Process "$env:TEMP\git.exe" -ArgumentList "/VERYSILENT" -Wait
# Reiniciar PowerShell para que git esté en PATH
```

### 1.5 Instalar Python via uv
```powershell
irm https://astral.sh/uv/install.ps1 | iex
# Reiniciar terminal
uv python install 3.13
```

### 1.6 Instalar Node.js 24
```powershell
# Descargar e instalar
Invoke-WebRequest -Uri "https://nodejs.org/dist/v24.0.0/node-v24.0.0-x64.msi" -OutFile "$env:TEMP\node.msi"
Start-Process msiexec.exe -ArgumentList "/i $env:TEMP\node.msi /quiet" -Wait
# Reiniciar terminal
node --version
```

### 1.7 Instalar Claude Code 2.1.69
```powershell
npm install -g @anthropic-ai/claude-code@2.1.69
claude --version
```

### 1.8 Instalar BcContainerHelper
```powershell
Install-Module -Name BcContainerHelper -Force -AllowClobber -AllowPrerelease -Scope CurrentUser
```

### 1.9 Instalar AL Tool (para AL MCP)
```powershell
# Requiere .NET SDK (ya incluido en Windows Server 2022)
dotnet tool install -g Microsoft.Dynamics.BusinessCentral.Development.Tools --version 17.0.33.55542
$env:PATH = "$env:USERPROFILE\.dotnet\tools;$env:PATH"
```

### 1.10 Desactivar Windows Defender (opcional, mejora rendimiento)
```powershell
# El antivirus ralentiza significativamente la compilación BC
Set-MpPreference -DisableRealtimeMonitoring $true
# O excluir las rutas:
Add-MpPreference -ExclusionPath "C:\bcbench", "C:\ProgramData\BcContainerHelper"
```

---

## Fase 2: Clonar proyecto y configurar entorno (~10 min)

### 2.1 Clonar BC-Bench
```powershell
cd C:\
git clone https://github.com/javiarmesto/BC-Bench.git bcbench
cd C:\bcbench
git checkout claude/explain-repo-usage-2rL3g
```

### 2.2 Instalar dependencias Python
```powershell
uv sync --all-groups
```

### 2.3 Configurar variables de entorno
```powershell
# Crear variables de entorno persistentes
[Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", "sk-ant-...", "User")
[Environment]::SetEnvironmentVariable("GITHUB_TOKEN", "ghp_...", "User")
[Environment]::SetEnvironmentVariable("BC_CONTAINER_PASSWORD", "BcBench2026!", "User")
[Environment]::SetEnvironmentVariable("BC_CONTAINER_NAME", "bcbench", "User")
[Environment]::SetEnvironmentVariable("BC_CONTAINER_USERNAME", "admin", "User")

# Recargar en sesión actual
$env:ANTHROPIC_API_KEY = [Environment]::GetEnvironmentVariable("ANTHROPIC_API_KEY", "User")
$env:GITHUB_TOKEN = [Environment]::GetEnvironmentVariable("GITHUB_TOKEN", "User")
$env:BC_CONTAINER_PASSWORD = [Environment]::GetEnvironmentVariable("BC_CONTAINER_PASSWORD", "User")
$env:BC_CONTAINER_NAME = [Environment]::GetEnvironmentVariable("BC_CONTAINER_NAME", "User")
$env:BC_CONTAINER_USERNAME = [Environment]::GetEnvironmentVariable("BC_CONTAINER_USERNAME", "User")
```

### 2.4 Verificar configuración ALDC
```powershell
# Debe mostrar: enabled: true para instructions, skills, agents
Get-Content src\bcbench\agent\shared\config.yaml | Select-String "enabled"
# Debe mostrar: name: al-developer-bench
Get-Content src\bcbench\agent\shared\config.yaml | Select-String "name:"
```

---

## Fase 3: Test rápido — Validar todo el pipeline (~45-60 min)

### 3.1 Ejecutar test run
```powershell
cd C:\bcbench
.\scripts\Setup-ALDCEvaluation.ps1 -TestRun -Category "bug-fix"
```

**Progreso esperado:**
```
[1/6] Validating prerequisites         (~2 min)  ← verifica todo lo instalado
[2/6] Installing Python dependencies   (~3 min)
[3/6] Resolving dataset entries         (~1 min)  ← selecciona 2 entries
[4/6] Setting up target repository      (~10 min) ← clona BCApps al commit base
[5/6] Setting up BC container           (~20 min) ← PRIMERA VEZ: descarga artefactos BC
[6/6] Running evaluation with ALDC      (~20 min) ← ejecuta Claude Code en cada entry
```

### 3.2 Troubleshooting común

| Error | Causa | Solución |
|---|---|---|
| "Hyper-V not available" | Trusted Launch habilitado | Recrear VM con Security Type = Standard |
| "Cannot connect to Docker" | Docker service parado | `Start-Service docker` |
| "BcContainerHelper not found" | Módulo no instalado | `Install-Module BcContainerHelper -Force` |
| "Authentication failed" | Token inválido/expirado | Regenerar GITHUB_TOKEN en GitHub Settings |
| "Disk space" | Disco lleno | Los artefactos BC ocupan ~15-20 GB |
| Container timeout (>30 min) | VM lenta o red lenta | Normal en primera ejecución, esperar |

### 3.3 Verificar resultados
```powershell
ls evaluation_results\
uv run bcbench result aggregate --input-dir evaluation_results
```

Si el test run pasa, la infraestructura está lista.

---

## Fase 4: Evaluación bug-fix — 3 escenarios

### 4.1 Primer paso: 1 entry con CompareAll (~2-4 horas)

Antes de lanzar todo el dataset, validar con 1 entry los 3 escenarios:

```powershell
.\scripts\Setup-ALDCEvaluation.ps1 `
    -InstanceId "microsoft__BCApps-5633" `
    -Category "bug-fix" `
    -CompareAll `
    -SkipContainerSetup -SkipRepoClone -RepoPath "C:\bcbench\testbed"
```

Esto ejecuta secuencialmente:
1. **ALDC + al-developer-bench** → `evaluation_results_aldc_al_developer_bench/`
2. **Baseline (sin ALDC)** → `evaluation_results_baseline/`
3. **ALDC + al-conductor-bench (TDD)** → `evaluation_results_aldc_al_conductor_bench/`

### 4.2 Segundo paso: Categoría bug-fix completa

Si el entry individual va bien, lanzar todo el dataset:

```powershell
.\scripts\Setup-ALDCEvaluation.ps1 `
    -Category "bug-fix" `
    -CompareAll `
    -SkipContainerSetup -SkipRepoClone -RepoPath "C:\bcbench\testbed"
```

**Tiempo estimado**: Con ~50 entries bug-fix × 3 escenarios × ~30 min/entry = **~75 horas**.
Dejar corriendo la VM — no apagar. Reconectar por RDP para ver progreso.

> **Alternativa para acelerar**: Correr solo 2 escenarios (`-CompareBaseline`) para empezar, y añadir el conductor después si los resultados son interesantes.

### 4.3 Tercer paso (futuro): test-generation con TDD

```powershell
.\scripts\Setup-ALDCEvaluation.ps1 `
    -Category "test-generation" `
    -CompareAll `
    -SkipContainerSetup -SkipRepoClone -RepoPath "C:\bcbench\testbed"
```

---

## Fase 5: Análisis de resultados

```powershell
# Agregar cada escenario
uv run bcbench result aggregate --input-dir evaluation_results_aldc_al_developer_bench
uv run bcbench result aggregate --input-dir evaluation_results_aldc_al_conductor_bench
uv run bcbench result aggregate --input-dir evaluation_results_baseline

# Notebooks de análisis visual (opcional)
uv run jupyter lab
```

---

## Resumen de tiempos y costes

| Fase | Tiempo | Coste Azure (~) |
|---|---|---|
| Crear VM Azure | 15 min | — |
| Instalar software en VM | 30-40 min | ~$0.50 |
| Configurar entorno | 10 min | — |
| Test run (2 entries) | 45-60 min | ~$0.80 |
| 1 entry × 3 escenarios | 2-4 horas | ~$3 |
| Dataset bug-fix completo × 3 escenarios | ~75 horas | ~$100 |
| **VM mensual (si se deja encendida)** | — | **~$280/mes** |

> **Tip**: Usa `az vm deallocate` para apagar la VM cuando no esté evaluando. Solo pagas disco (~$20/mes).

---

## Checklist para mañana

### Mañana temprano (setup ~1 hora)
- [ ] Crear VM Azure (Standard_D8s_v3, Security Type = Standard, 256 GB disk)
- [ ] Conectar RDP
- [ ] Instalar Hyper-V + reiniciar
- [ ] Instalar Docker, PowerShell 7, Git, uv, Node.js, Claude Code, BcContainerHelper, AL Tool
- [ ] Desactivar Windows Defender (o configurar exclusiones)

### Mañana media mañana (config ~15 min)
- [ ] Clonar BC-Bench, checkout branch
- [ ] `uv sync --all-groups`
- [ ] Configurar variables de entorno (ANTHROPIC_API_KEY, GITHUB_TOKEN, BC_CONTAINER_PASSWORD)
- [ ] Verificar config.yaml (ALDC enabled)

### Mañana al mediodía (validación ~1 hora)
- [ ] Ejecutar `-TestRun` (2 entries)
- [ ] Verificar que genera resultados correctos

### Mañana por la tarde (lanzar evaluación)
- [ ] Ejecutar 1 entry con `-CompareAll` para validar los 3 escenarios
- [ ] Si todo OK → lanzar dataset bug-fix completo con `-CompareAll`
- [ ] Dejar corriendo la VM (~75 horas para dataset completo)

### Cuando termine
- [ ] Agregar resultados
- [ ] Comparar métricas: baseline vs al-developer-bench vs al-conductor-bench
- [ ] Decidir si lanzar test-generation
- [ ] Apagar VM (`az vm deallocate`) para ahorrar costes

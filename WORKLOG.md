# BC-Bench Worklog

## 2026-04-08 — Claude vs Copilot comparison on bug-fix

### Estado al cerrar

#### Instancias evaluadas
| Instance | Agent | Scenarios completados | Resultados en repo |
|---|---|---|---|
| `microsoft__BCApps-5633` | Claude Code (claude-sonnet-4-6) | baseline ×3, aldc-developer ×3, aldc-conductor ×3 | ✅ `notebooks/result/bug-fix/baseline-sonnet-4-6*` |
| `microsoft__BCApps-5633` | GitHub Copilot (claude-sonnet-4.6) | baseline, aldc-developer, aldc-conductor | ⏳ corriendo en VM / pendiente push |

#### Instancias pendientes
- `microsoft__BCApps-4822` — commit `f0b7291e`, 1 archivo, +7 líneas (ShpfyCompanyAPI — pasar Customer completo, no solo GUID)
- `microsoft__BCApps-4699`, `microsoft__BCApps-4766` — no iniciadas

### Patrón observado en 5633
- **ALDC**: 0/3 pasa en todos los escenarios (developer y conductor), para ambos agentes
- **Baseline Claude**: 1/3 (no determinista)
- **Root cause**: Mock `UnitTestExportShipmentThirdParty` verifica `FulfillmentRequest count = 0` pero los agentes consultan `Shpfy Shop Location` en runtime — tabla no poblada en mock → count = 1 → fallo

### Cambios en el repo (branch: `claude/explain-repo-usage-2rL3g`)
- `scripts/Setup-ALDCEvaluation.ps1`: ValidateSet de `-Model` ampliado para incluir formatos Copilot (puntos, no guiones)
- `scripts/Run-FullComparison.ps1`: **NUEVO** — script "fire and forget" que lanza 6 escenarios (Claude + Copilot × baseline/aldc-dev/aldc-conductor), recoge resultados, genera report .md y hace git push automático

### Cómo continuar mañana

**1. Pull en VM y lanzar 5633 completo (si no terminó hoy):**
```powershell
cd C:\bcbench
git pull origin claude/explain-repo-usage-2rL3g
$env:GMAIL_APP_PASSWORD = "<tu-app-password>"
cd scripts
.\Run-FullComparison.ps1 -InstanceId "microsoft__BCApps-5633" -SkipContainerSetup -SkipRepoClone -PauseBetweenScenarios 30 -EmailTo "javiarmesto@gmail.com"
```

**2. Siguiente instancia (4822) — distinto commit, sin -SkipRepoClone:**
```powershell
.\Run-FullComparison.ps1 -InstanceId "microsoft__BCApps-4822" -SkipContainerSetup -PauseBetweenScenarios 30 -EmailTo "javiarmesto@gmail.com"
```
> ⚠️ Sin `-SkipRepoClone` porque el commit es diferente (`f0b7291e` vs `2607952`)

**3. Apagar VM cuando no esté en uso:**
```powershell
# Desde local ou desde la VM:
az vm deallocate --resource-group <rg> --name vm-bcbench
```

### Notas técnicas
- VM: `vm-bcbench`, IP `52.142.212.229`, user `azureuser`, cwd `C:\bcbench`
- Fork activo: `javiarmesto/BC-Bench`, branch `claude/explain-repo-usage-2rL3g`
- Claude usa modelo `claude-sonnet-4-6` (guiones); Copilot usa `claude-sonnet-4.6` (puntos) — diferencia clave
- Output dirs en VM: `eval_claude_baseline/`, `eval_claude_aldc_developer/`, `eval_claude_aldc_conductor/`, idem `eval_copilot_*`

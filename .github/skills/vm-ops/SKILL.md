# VM Operations for BC-Bench

## VM details

- Name: `vm-bcbench`
- Resource group: `rg-bcbench`
- Region: West Europe
- Size: Standard_D8s_v3
- OS: Windows Server 2022
- Bcbench root: `C:\bcbench`
- Branch: `claude/explain-repo-usage-2rL3g`

## Common operations

### Start / stop

```powershell
# Start
az vm start -g rg-bcbench -n vm-bcbench

# Deallocate (stop billing)
az vm deallocate -g rg-bcbench -n vm-bcbench

# Check state + IP
az vm show -g rg-bcbench -n vm-bcbench -d --query "{powerState:powerState,publicIps:publicIps}" -o json
```

### Run a full comparison (paste on VM after RDP)

```powershell
# 1. Pull latest scripts
git -C C:\bcbench pull origin claude/explain-repo-usage-2rL3g

# 2. Set credentials
$env:GMAIL_APP_PASSWORD = "your-app-password"

# 3. Run with default model (sonnet)
C:\bcbench\scripts\Run-FullComparison.ps1 `
    -InstanceIds "microsoft__BCApps-4822" `
    -OnlyMissing -EmailTo "javiarmesto@gmail.com" -AutoShutdown

# 3b. Run with a different model family (e.g., opus)
C:\bcbench\scripts\Run-FullComparison.ps1 `
    -LlmFamily opus `
    -OnlyMissing -EmailTo "javiarmesto@gmail.com" -AutoShutdown
```

### Run pilot NAV-27.0 batch

```powershell
git -C C:\bcbench pull origin claude/explain-repo-usage-2rL3g
$env:GMAIL_APP_PASSWORD = "your-app-password"
C:\bcbench\scripts\Run-FullComparison.ps1 `
    -InstanceIds "microsoftInternal__NAV-213629","microsoftInternal__NAV-227358",`
                 "microsoftInternal__NAV-217974","microsoftInternal__NAV-220314",`
                 "microsoftInternal__NAV-224009" `
    -OnlyMissing -EmailTo "javiarmesto@gmail.com" -AutoShutdown
```

### Collect results without re-running

```powershell
C:\bcbench\scripts\Run-FullComparison.ps1 -SkipClaude -SkipCopilot -InstanceIds "..."
# NOTE: This still runs the collect + report + push phases
```

### Check what results exist

```powershell
Get-ChildItem C:\bcbench\notebooks\result\bug-fix -Recurse -Filter "*.jsonl" |
    Select-Object Directory, Name | Format-Table -AutoSize
```

### Check Docker containers

```powershell
docker ps -a
docker rm -f $(docker ps -aq)  # Clean all containers
```

## Instructions

When the user asks to:

- **Start the VM** → run `az vm start` and wait for running state
- **Check VM status** → run `az vm show` with powerState query
- **Get IP** → parse `publicIps` from `az vm show -d`
- **Run evaluations** → provide the exact PowerShell block above, remind to `git pull` first
- **Stop VM** → remind to use `deallocate` (not just `stop`) to avoid charges

<#
.SYNOPSIS
    Run all evaluation scenarios for Claude and GitHub Copilot, collect results, generate report, and push to repo.
.PARAMETER InstanceIds
    One or more dataset entry IDs to evaluate. Instances sharing the same env_version reuse the BC container.
    Default: "microsoft__BCApps-5633"
.PARAMETER RepoPath
    Path to the testbed repository. Default: C:\bcbench\testbed
.PARAMETER BcbenchRoot
    Root of the bcbench repo. Default: C:\bcbench
.PARAMETER GitBranch
    Branch to push results to. Default: claude/explain-repo-usage-2rL3g
.PARAMETER PauseBetweenScenarios
    Seconds to wait between scenarios. Default: 30
.PARAMETER SkipClaude
    Skip Claude Code scenarios.
.PARAMETER SkipCopilot
    Skip GitHub Copilot scenarios.
.PARAMETER SkipContainerSetup
    Use existing BC container.
.PARAMETER SkipRepoClone
    Use existing testbed repo (only if all entries share same commit).
.PARAMETER EmailTo
    Optional: send summary email to this address (requires Gmail app password in $env:GMAIL_APP_PASSWORD).
.PARAMETER OnlyMissing
    Skip scenarios where a result jsonl for InstanceId already exists (useful to resume failed runs).
.PARAMETER AutoShutdown
    Shut down the machine after all scenarios, collect and push are done (and email sent).
.PARAMETER LlmFamily
    Model family name (e.g., "sonnet", "opus"). Used to derive model strings:
    Claude Code = claude-{family}-4-6, Copilot = claude-{family}-4.6
    Default: "sonnet"
.EXAMPLE
    # Pull latest scripts first, then run
    git -C C:\bcbench pull origin claude/explain-repo-usage-2rL3g
    .\Run-FullComparison.ps1 -InstanceIds "microsoft__BCApps-4822" -OnlyMissing -EmailTo "you@gmail.com" -AutoShutdown
.EXAMPLE
    # Run with Opus 4.6 as the LLM
    .\Run-FullComparison.ps1 -LlmFamily opus -OnlyMissing -EmailTo "you@gmail.com" -AutoShutdown
#>
param(
    [string[]]$InstanceIds = @("microsoft__BCApps-5633"),
    [string]$RepoPath = "C:\bcbench\testbed",
    [string]$BcbenchRoot = "C:\bcbench",
    [string]$GitBranch = "claude/explain-repo-usage-2rL3g",
    [int]$PauseBetweenScenarios = 30,
    [switch]$SkipClaude,
    [switch]$SkipCopilot,
    [switch]$SkipContainerSetup,
    [switch]$SkipRepoClone,
    [string]$EmailTo = "",
    [switch]$OnlyMissing,
    [switch]$AutoShutdown,
    [string]$LlmFamily = "sonnet"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$StartTime = Get-Date

# ── Model strings derived from LlmFamily ─────────────────────────────────
$claudeModel = "claude-$LlmFamily-4-6"
$copilotModel = "claude-$LlmFamily-4.6"
$modelSuffix = "$LlmFamily-4-6"

# ── Load env_version per instance from dataset ───────────────────────────────
$envVersions = @{}
$datasetPath = Join-Path $BcbenchRoot "dataset/bcbench.jsonl"
if (Test-Path $datasetPath) {
    foreach ($line in (Get-Content $datasetPath)) {
        $entry = $line | ConvertFrom-Json
        if ($InstanceIds -contains $entry.instance_id) {
            $envVersions[$entry.instance_id] = $entry.environment_setup_version
        }
    }
}

function Write-Header($msg) {
    Write-Host "`n$('=' * 70)" -ForegroundColor Cyan
    Write-Host " $msg" -ForegroundColor Cyan
    Write-Host "$('=' * 70)" -ForegroundColor Cyan
}

function Write-Step($msg) { Write-Host "  [..] $msg" -ForegroundColor Yellow }
function Write-Ok($msg) { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "  [!!] $msg" -ForegroundColor Red }

# ── Scenario definitions ────────────────────────────────────────────────────
$scenarios = @(
    @{ Agent = "claude"; Scenario = "baseline"; Model = $claudeModel; OutDir = "eval_claude_baseline_$modelSuffix" }
    @{ Agent = "claude"; Scenario = "aldc-developer"; Model = $claudeModel; OutDir = "eval_claude_aldc_developer_$modelSuffix" }
    @{ Agent = "claude"; Scenario = "aldc-conductor"; Model = $claudeModel; OutDir = "eval_claude_aldc_conductor_$modelSuffix" }
    @{ Agent = "copilot"; Scenario = "baseline"; Model = $copilotModel; OutDir = "eval_copilot_baseline_$modelSuffix" }
    @{ Agent = "copilot"; Scenario = "aldc-developer"; Model = $copilotModel; OutDir = "eval_copilot_aldc_developer_$modelSuffix" }
    @{ Agent = "copilot"; Scenario = "aldc-conductor"; Model = $copilotModel; OutDir = "eval_copilot_aldc_conductor_$modelSuffix" }
)

# ── Run evaluations ──────────────────────────────────────────────────────────
Write-Header "RUNNING $($scenarios.Count) SCENARIOS × $($InstanceIds.Count) INSTANCES"

$results = @()
$scriptPath = Join-Path $PSScriptRoot "Setup-ALDCEvaluation.ps1"
$baseSkipArgs = @{}
if ($SkipContainerSetup) { $baseSkipArgs["SkipContainerSetup"] = $true }
if ($SkipRepoClone) { $baseSkipArgs["SkipRepoClone"] = $true }

$prevEnvVersion = $null
$instanceCount = $InstanceIds.Count

for ($instIdx = 0; $instIdx -lt $instanceCount; $instIdx++) {
    $InstanceId = $InstanceIds[$instIdx]
    $envVersion = $envVersions[$InstanceId]
    Write-Header "INSTANCE [$($instIdx+1)/$instanceCount]: $InstanceId  (BC $envVersion)"

    for ($i = 0; $i -lt $scenarios.Count; $i++) {
        $s = $scenarios[$i]

        if ($s.Agent -eq "claude" -and $SkipClaude) { continue }
        if ($s.Agent -eq "copilot" -and $SkipCopilot) { continue }

        if ($OnlyMissing) {
            $existingDir = Get-ChildItem $BcbenchRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "$($s.OutDir)*" } | Select-Object -First 1
            if ($existingDir) {
                $hit = Get-ChildItem $existingDir.FullName -Recurse -Filter "$InstanceId.jsonl" -ErrorAction SilentlyContinue
                if ($hit) {
                    Write-Ok "  Skipping $($s.Agent) $($s.Scenario) — result already exists"
                    continue
                }
            }
        }

        Write-Header "[$($instIdx+1)/$instanceCount] $InstanceId | $($s.Agent.ToUpper()) — $($s.Scenario)"

        # Reuse container across instances if same BC version
        $runSkipArgs = $baseSkipArgs.Clone()
        if ($null -ne $prevEnvVersion -and $prevEnvVersion -eq $envVersion -and -not $SkipContainerSetup) {
            $runSkipArgs["SkipContainerSetup"] = $true
        }

        $outDir = Join-Path $BcbenchRoot $s.OutDir
        $t0 = Get-Date

        try {
            & $scriptPath `
                -InstanceId $InstanceId `
                -Agent $s.Agent `
                -Model $s.Model `
                -Scenario $s.Scenario `
                -RepoPath $RepoPath `
                -OutputDir $outDir `
                @runSkipArgs
            $exitCode = $LASTEXITCODE
        }
        catch {
            $exitCode = 1
            Write-Fail "Script threw: $_"
        }

        $prevEnvVersion = $envVersion
        $elapsed = [int]((Get-Date) - $t0).TotalMinutes
        $results += [PSCustomObject]@{
            Instance = $InstanceId
            Agent    = $s.Agent
            Scenario = $s.Scenario
            ExitCode = $exitCode
            Minutes  = $elapsed
        }

        if ($exitCode -eq 0) { Write-Ok "Completed in ${elapsed}m" }
        else { Write-Fail "Failed (exit $exitCode) after ${elapsed}m" }

        # Clean up BC containers and unlock testbed between runs
        $isLastRun = ($instIdx -eq $instanceCount - 1) -and ($i -eq $scenarios.Count - 1)
        if (-not $isLastRun) {
            Write-Step "Cleaning BC containers..."
            docker ps -aq | ForEach-Object { docker rm -f $_ 2>$null }
            Start-Sleep -Seconds 3
            if ($PauseBetweenScenarios -gt 0) {
                Write-Step "Pausing $PauseBetweenScenarios seconds..."
                Start-Sleep -Seconds $PauseBetweenScenarios
            }
        }
    }
}

# ── Collect results into repo ────────────────────────────────────────────────
Write-Header "COLLECTING RESULTS"

$resultBase = Join-Path $BcbenchRoot "notebooks/result/bug-fix"
$scenarioTags = @{
    "baseline"       = "baseline"
    "aldc-developer" = "aldc_al_developer_bench"
    "aldc-conductor" = "aldc_al_conductor_bench"
}
$dirMap = @{}
foreach ($s in $scenarios) {
    $key = "$($s.OutDir)_$($scenarioTags[$s.Scenario])"
    $tag = $scenarioTags[$s.Scenario] -replace '_', '-'
    $dirMap[$key] = "$($s.Agent)-$tag-$modelSuffix"
}

foreach ($key in $dirMap.Keys) {
    $srcDir = Join-Path $BcbenchRoot $key
    if (-not (Test-Path $srcDir)) {
        Write-Step "Skipped $key (not found)"
        continue
    }
    # Support both claude_code_test_run and copilot_test_run subdirs
    $subDir = Get-ChildItem $srcDir -Directory | Select-Object -First 1
    if ($null -eq $subDir) {
        Write-Step "Skipped $key (no subdir)"
        continue
    }
    $src = Join-Path $subDir.FullName "*.jsonl"
    $dst = Join-Path $resultBase $dirMap[$key]
    New-Item -ItemType Directory -Path $dst -Force | Out-Null
    Copy-Item $src $dst -ErrorAction SilentlyContinue
    Write-Ok "Copied $key ($($subDir.Name)) → $($dirMap[$key])"
}

# ── Parse JSONL for report ───────────────────────────────────────────────────
Write-Header "GENERATING REPORT"

$reportRows = @()
foreach ($InstanceId in $InstanceIds) {
    foreach ($key in $dirMap.Keys) {
        $jsonl = Join-Path $resultBase "$($dirMap[$key])\$InstanceId.jsonl"
        if (-not (Test-Path $jsonl)) { continue }
        $r = Get-Content $jsonl -First 1 | ConvertFrom-Json
        $agentLabel = if ($key -like "eval_claude*") { "Claude Code" } else { "GitHub Copilot" }
        $scenarioLabel = switch -Wildcard ($key) {
            "*baseline*" { "Baseline" }
            "*aldc_developer*" { "ALDC + al-developer-bench" }
            "*aldc_conductor*" { "ALDC + al-conductor-bench" }
        }
        $reportRows += [PSCustomObject]@{
            Instance = $InstanceId
            Agent    = $agentLabel
            Scenario = $scenarioLabel
            Resolved = if ($r.resolved) { "✅" } else { "❌" }
            Build    = if ($r.build) { "✅" } else { "❌" }
            Turns    = $r.metrics.turn_count
            Time     = "$([int]$r.metrics.execution_time)s"
            Tokens   = [int](($r.metrics.prompt_tokens + $r.metrics.completion_tokens) / 1000)
        }
    }
}

$date = (Get-Date).ToString("yyyy-MM-dd")
$totalElapsed = [int]((Get-Date) - $StartTime).TotalMinutes
$instanceLabel = ($InstanceIds | ForEach-Object { $_ -replace 'microsoft__BCApps-', 'BCApps-' -replace 'microsoftInternal__NAV-', 'NAV-' }) -join ", "

# Build markdown table (with Instance column when multiple)
$multiInstance = $InstanceIds.Count -gt 1
if ($multiInstance) {
    $mdTable = "| Instance | Agent | Scenario | Resolved | Build | Turns | Time | Tokens (K) |`n"
    $mdTable += "|----------|-------|----------|:--------:|:-----:|------:|-----:|-----------:|`n"
    foreach ($row in $reportRows) {
        $inst = $row.Instance -replace 'microsoft__BCApps-', 'BCApps-' -replace 'microsoftInternal__NAV-', 'NAV-'
        $mdTable += "| $inst | $($row.Agent) | $($row.Scenario) | $($row.Resolved) | $($row.Build) | $($row.Turns) | $($row.Time) | $($row.Tokens)K |`n"
    }
}
else {
    $mdTable = "| Agent | Scenario | Resolved | Build | Turns | Time | Tokens (K) |`n"
    $mdTable += "|-------|----------|:--------:|:-----:|------:|-----:|-----------:|`n"
    foreach ($row in $reportRows) {
        $mdTable += "| $($row.Agent) | $($row.Scenario) | $($row.Resolved) | $($row.Build) | $($row.Turns) | $($row.Time) | $($row.Tokens)K |`n"
    }
}

$mdContent = @"
# Evaluation Report: $instanceLabel

**Date:** $date
**Instances:** $($InstanceIds -join ', ')
**Model:** $claudeModel (Claude) / $copilotModel (Copilot)
**Total time:** ~${totalElapsed} minutes

## Results

$mdTable

## Notes

> Generated by Run-FullComparison.ps1 on $date
"@

$safeLabel = $instanceLabel -replace '[^a-zA-Z0-9-]', '_'
$reportPath = Join-Path $BcbenchRoot "notebooks/result/bug-fix/report-${safeLabel}-${date}.md"
$mdContent | Set-Content -Path $reportPath -Encoding UTF8
Write-Ok "Report written: $reportPath"

# Print summary to console
Write-Header "SUMMARY"
$reportRows | Format-Table -AutoSize

# ── Git push ────────────────────────────────────────────────────────────────
Write-Header "PUSHING TO REPO"

Push-Location $BcbenchRoot
try {
    git add notebooks/result/bug-fix/
    git commit -m "results($modelSuffix): $instanceLabel full comparison claude+copilot ($date)"
    git push origin $GitBranch
    Write-Ok "Pushed to $GitBranch"
}
catch {
    Write-Fail "Git push failed: $_"
}
finally {
    Pop-Location
}

# ── Email (optional) ────────────────────────────────────────────────────────
if ($EmailTo -ne "") {
    Write-Header "SENDING EMAIL"
    $gmailPass = $env:GMAIL_APP_PASSWORD
    if (-not $gmailPass) {
        Write-Fail "Set `$env:GMAIL_APP_PASSWORD (Gmail app password) to enable email"
    }
    else {
        try {
            $cred = [System.Management.Automation.PSCredential]::new(
                "javiarmesto@gmail.com",
                ($gmailPass | ConvertTo-SecureString -AsPlainText -Force)
            )
            $body = "BC-Bench evaluation complete for $instanceLabel ($date).`n`n" + ($reportRows | Format-Table -AutoSize | Out-String)
            Send-MailMessage `
                -To $EmailTo `
                -From "javiarmesto@gmail.com" `
                -Subject "[BC-Bench] Evaluation complete: $instanceLabel ($date)" `
                -Body $body `
                -SmtpServer "smtp.gmail.com" `
                -Port 587 `
                -UseSsl `
                -Credential $cred
            Write-Ok "Email sent to $EmailTo"
        }
        catch {
            Write-Fail "Email failed: $_"
        }
    }
}

Write-Header "DONE — Total time: ${totalElapsed} minutes"

if ($AutoShutdown) {
    Write-Step "AutoShutdown: shutting down in 60 seconds... (Ctrl+C to cancel)"
    Start-Sleep -Seconds 60
    Stop-Computer -Force
}

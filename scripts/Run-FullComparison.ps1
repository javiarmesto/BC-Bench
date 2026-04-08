<#
.SYNOPSIS
    Run all evaluation scenarios for Claude and GitHub Copilot, collect results, generate report, and push to repo.
.PARAMETER InstanceId
    Dataset entry to evaluate. Default: "microsoft__BCApps-5633"
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
.EXAMPLE
    .\Run-FullComparison.ps1 -InstanceId "microsoft__BCApps-5633" -SkipContainerSetup -SkipRepoClone
#>
param(
    [string]$InstanceId = "microsoft__BCApps-5633",
    [string]$RepoPath = "C:\bcbench\testbed",
    [string]$BcbenchRoot = "C:\bcbench",
    [string]$GitBranch = "claude/explain-repo-usage-2rL3g",
    [int]$PauseBetweenScenarios = 30,
    [switch]$SkipClaude,
    [switch]$SkipCopilot,
    [switch]$SkipContainerSetup,
    [switch]$SkipRepoClone,
    [string]$EmailTo = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$StartTime = Get-Date

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
    @{ Agent = "claude"; Scenario = "baseline"; Model = "claude-sonnet-4-6"; OutDir = "eval_claude_baseline" }
    @{ Agent = "claude"; Scenario = "aldc-developer"; Model = "claude-sonnet-4-6"; OutDir = "eval_claude_aldc_developer" }
    @{ Agent = "claude"; Scenario = "aldc-conductor"; Model = "claude-sonnet-4-6"; OutDir = "eval_claude_aldc_conductor" }
    @{ Agent = "copilot"; Scenario = "baseline"; Model = "claude-sonnet-4.6"; OutDir = "eval_copilot_baseline" }
    @{ Agent = "copilot"; Scenario = "aldc-developer"; Model = "claude-sonnet-4.6"; OutDir = "eval_copilot_aldc_developer" }
    @{ Agent = "copilot"; Scenario = "aldc-conductor"; Model = "claude-sonnet-4.6"; OutDir = "eval_copilot_aldc_conductor" }
)

# ── Run evaluations ──────────────────────────────────────────────────────────
Write-Header "RUNNING $($scenarios.Count) SCENARIOS FOR $InstanceId"

$results = @()
$scriptPath = Join-Path $PSScriptRoot "Setup-ALDCEvaluation.ps1"
$skipArgs = @{}
if ($SkipContainerSetup) { $skipArgs["SkipContainerSetup"] = $true }
if ($SkipRepoClone) { $skipArgs["SkipRepoClone"] = $true }

for ($i = 0; $i -lt $scenarios.Count; $i++) {
    $s = $scenarios[$i]

    if ($s.Agent -eq "claude" -and $SkipClaude) { continue }
    if ($s.Agent -eq "copilot" -and $SkipCopilot) { continue }

    Write-Header "[$($i+1)/$($scenarios.Count)] $($s.Agent.ToUpper()) — $($s.Scenario)"

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
            @skipArgs
        $exitCode = $LASTEXITCODE
    }
    catch {
        $exitCode = 1
        Write-Fail "Script threw: $_"
    }

    $elapsed = [int]((Get-Date) - $t0).TotalMinutes
    $results += [PSCustomObject]@{
        Agent    = $s.Agent
        Scenario = $s.Scenario
        Model    = $s.Model
        OutDir   = $outDir
        ExitCode = $exitCode
        Minutes  = $elapsed
    }

    if ($exitCode -eq 0) { Write-Ok "Completed in ${elapsed}m" }
    else { Write-Fail "Failed (exit $exitCode) after ${elapsed}m" }

    # Pause between scenarios (skip after the last one)
    if ($i -lt ($scenarios.Count - 1) -and $PauseBetweenScenarios -gt 0) {
        Write-Step "Pausing $PauseBetweenScenarios seconds..."
        Start-Sleep -Seconds $PauseBetweenScenarios
    }
}

# ── Collect results into repo ────────────────────────────────────────────────
Write-Header "COLLECTING RESULTS"

$safeInstance = $InstanceId -replace "__", "-" -replace "/", "-"
$resultBase = Join-Path $BcbenchRoot "notebooks/result/bug-fix"
$dirMap = @{
    "eval_claude_baseline"        = "claude-baseline-sonnet-4-6"
    "eval_claude_aldc_developer"  = "claude-aldc-al-developer-bench-sonnet-4-6"
    "eval_claude_aldc_conductor"  = "claude-aldc-al-conductor-bench-sonnet-4-6"
    "eval_copilot_baseline"       = "copilot-baseline-sonnet-4-6"
    "eval_copilot_aldc_developer" = "copilot-aldc-al-developer-bench-sonnet-4-6"
    "eval_copilot_aldc_conductor" = "copilot-aldc-al-conductor-bench-sonnet-4-6"
}

foreach ($key in $dirMap.Keys) {
    $src = Join-Path $BcbenchRoot "$key\claude_code_test_run\*.jsonl"
    $dst = Join-Path $resultBase $dirMap[$key]
    if (Test-Path (Join-Path $BcbenchRoot $key)) {
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
        Copy-Item $src $dst -ErrorAction SilentlyContinue
        Write-Ok "Copied $key → $($dirMap[$key])"
    }
    else {
        Write-Step "Skipped $key (not found)"
    }
}

# ── Parse JSONL for report ───────────────────────────────────────────────────
Write-Header "GENERATING REPORT"

function Read-Result($dir) {
    $jsonl = Join-Path $resultBase "$dir\$InstanceId.jsonl"
    if (-not (Test-Path $jsonl)) { return $null }
    $line = Get-Content $jsonl -First 1
    return ($line | ConvertFrom-Json)
}

$reportRows = @()
foreach ($key in $dirMap.Keys) {
    $r = Read-Result $dirMap[$key]
    if ($null -eq $r) { continue }
    $agentLabel = if ($key -like "eval_claude*") { "Claude Code" } else { "GitHub Copilot" }
    $scenarioLabel = switch -Wildcard ($key) {
        "*baseline*" { "Baseline" }
        "*aldc_developer*" { "ALDC + al-developer-bench" }
        "*aldc_conductor*" { "ALDC + al-conductor-bench" }
    }
    $reportRows += [PSCustomObject]@{
        Agent    = $agentLabel
        Scenario = $scenarioLabel
        Resolved = if ($r.resolved) { "✅" } else { "❌" }
        Build    = if ($r.build) { "✅" } else { "❌" }
        Turns    = $r.metrics.turn_count
        Time     = "$([int]$r.metrics.execution_time)s"
        Tokens   = [int](($r.metrics.prompt_tokens + $r.metrics.completion_tokens) / 1000)
    }
}

$date = (Get-Date).ToString("yyyy-MM-dd")
$totalElapsed = [int]((Get-Date) - $StartTime).TotalMinutes

# Build markdown table
$mdTable = "| Agent | Scenario | Resolved | Build | Turns | Time | Tokens (K) |`n"
$mdTable += "|-------|----------|:--------:|:-----:|------:|-----:|-----------:|`n"
foreach ($row in $reportRows) {
    $mdTable += "| $($row.Agent) | $($row.Scenario) | $($row.Resolved) | $($row.Build) | $($row.Turns) | $($row.Time) | $($row.Tokens)K |`n"
}

$mdContent = @"
# Evaluation Report: $InstanceId

**Date:** $date
**Model:** claude-sonnet-4-6 (Claude) / claude-sonnet-4.6 (Copilot)
**Total time:** ~${totalElapsed} minutes

## Results

$mdTable

## Key Findings

- Claude baseline pass@1 across runs: see individual run directories
- ALDC impact: compare Baseline vs ALDC rows for each agent
- Both agents face the same test mock constraint: `FulfillmentRequest count check`

## Notes

> Generated by `Run-FullComparison.ps1` on $date
"@

$reportPath = Join-Path $BcbenchRoot "notebooks/result/bug-fix/report-$safeInstance-$date.md"
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
    git commit -m "results: $InstanceId full comparison claude+copilot ($date)"
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
            $body = "BC-Bench evaluation complete for $InstanceId ($date).`n`n" + ($reportRows | Format-Table -AutoSize | Out-String)
            Send-MailMessage `
                -To $EmailTo `
                -From "javiarmesto@gmail.com" `
                -Subject "[BC-Bench] Evaluation complete: $InstanceId ($date)" `
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

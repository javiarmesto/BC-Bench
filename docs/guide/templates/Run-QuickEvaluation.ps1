<#
.SYNOPSIS
    Quick single-instance evaluation script for BC-Bench.
    Ready-to-use template — fill in the parameters and run on your VM.
.DESCRIPTION
    Evaluates one dataset entry with one agent and one scenario.
    Designed for first-time users following the BC-Bench guide.

    Guide reference: docs/guide/04-baselines-y-scripts-vm.md
.PARAMETER InstanceId
    Dataset entry ID to evaluate (e.g., "microsoft__BCApps-4822").
.PARAMETER Agent
    Agent to use: "claude" or "copilot". Default: "claude"
.PARAMETER Model
    LLM model. Default: "claude-sonnet-4-6"
.PARAMETER Category
    Evaluation category: "bug-fix" or "test-generation". Default: "bug-fix"
.PARAMETER AlMcp
    Enable the AL MCP server for richer tool access. Default: $true
.EXAMPLE
    .\Run-QuickEvaluation.ps1 -InstanceId "microsoft__BCApps-4822"
.EXAMPLE
    .\Run-QuickEvaluation.ps1 -InstanceId "microsoft__BCApps-4822" -Agent copilot -Model "claude-sonnet-4.6"
.EXAMPLE
    .\Run-QuickEvaluation.ps1 -InstanceId "microsoft__BCApps-4822" -Category test-generation
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$InstanceId,

    [ValidateSet("claude", "copilot")]
    [string]$Agent = "claude",

    [string]$Model = "claude-sonnet-4-6",

    [ValidateSet("bug-fix", "test-generation")]
    [string]$Category = "bug-fix",

    [switch]$AlMcp = $true
)

$ErrorActionPreference = "Stop"

# ── Paths ──────────────────────────────────────────────────────────────
$BcbenchRoot = "C:\bcbench"
$RepoPath    = "C:\bcbench\testbed"
$OutputDir   = Join-Path $BcbenchRoot "evaluation_results"
$ScriptsDir  = Join-Path $BcbenchRoot "scripts"

# ── Validate environment ──────────────────────────────────────────────
Write-Host "=== BC-Bench Quick Evaluation ===" -ForegroundColor Cyan
Write-Host "Instance:  $InstanceId"
Write-Host "Agent:     $Agent"
Write-Host "Model:     $Model"
Write-Host "Category:  $Category"
Write-Host "AL MCP:    $AlMcp"
Write-Host ""

$errors = @()
if ($Agent -eq "claude" -and -not $env:ANTHROPIC_API_KEY) { $errors += "ANTHROPIC_API_KEY not set" }
if (-not $env:BC_CONTAINER_PASSWORD) { $errors += "BC_CONTAINER_PASSWORD not set" }
if (-not (Test-Path $BcbenchRoot)) { $errors += "BC-Bench not found at $BcbenchRoot" }

if ($errors.Count -gt 0) {
    Write-Host "ERRORS:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

# ── Step 1: Setup container and repository ────────────────────────────
Write-Host "`n[1/3] Setting up container and repository..." -ForegroundColor Yellow

& (Join-Path $ScriptsDir "Setup-ContainerAndRepository.ps1") `
    -InstanceId $InstanceId `
    -RepoPath $RepoPath

Write-Host "  [OK] Container and repository ready" -ForegroundColor Green

# ── Step 2: Run evaluation ────────────────────────────────────────────
Write-Host "`n[2/3] Running evaluation..." -ForegroundColor Yellow

$timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
$runId = "${Agent}_${Category}_${timestamp}"

$evalArgs = @{
    "entry_id"        = $InstanceId
    "container-name"  = $env:BC_CONTAINER_NAME ?? "bcbench"
    "username"        = $env:BC_CONTAINER_USERNAME ?? "admin"
    "password"        = $env:BC_CONTAINER_PASSWORD
    "category"        = $Category
    "model"           = $Model
    "repo-path"       = $RepoPath
    "output-dir"      = $OutputDir
    "run-id"          = $runId
}

$alMcpFlag = if ($AlMcp) { "--al-mcp" } else { "" }

Push-Location $BcbenchRoot
try {
    $cmd = "uv run bcbench evaluate $Agent $InstanceId --category $Category --model $Model --container-name $($evalArgs['container-name']) --username $($evalArgs['username']) --password $($evalArgs['password']) --repo-path $RepoPath --output-dir $OutputDir --run-id $runId $alMcpFlag"
    Write-Host "  CMD: $cmd" -ForegroundColor DarkGray
    Invoke-Expression $cmd

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Evaluation completed" -ForegroundColor Green
    } else {
        Write-Host "  [!!] Evaluation finished with exit code $LASTEXITCODE" -ForegroundColor Red
    }
}
finally {
    Pop-Location
}

# ── Step 3: Show results ──────────────────────────────────────────────
Write-Host "`n[3/3] Results summary..." -ForegroundColor Yellow

$resultFile = Join-Path $OutputDir $runId "$InstanceId.jsonl"
if (Test-Path $resultFile) {
    $result = Get-Content $resultFile -First 1 | ConvertFrom-Json
    Write-Host ""
    Write-Host "  Instance:  $($result.instance_id)" -ForegroundColor White
    Write-Host "  Resolved:  $(if ($result.resolved) { 'YES' } else { 'NO' })" -ForegroundColor $(if ($result.resolved) { 'Green' } else { 'Red' })
    Write-Host "  Build:     $(if ($result.build) { 'YES' } else { 'NO' })" -ForegroundColor $(if ($result.build) { 'Green' } else { 'Red' })
    if ($result.metrics) {
        Write-Host "  Time:      $([int]$result.metrics.execution_time) seconds"
        Write-Host "  Turns:     $($result.metrics.turn_count)"
        Write-Host "  Tokens:    $([int](($result.metrics.prompt_tokens + $result.metrics.completion_tokens) / 1000))K"
    }
    Write-Host ""
    Write-Host "  Full result: $resultFile" -ForegroundColor DarkGray
} else {
    Write-Host "  Result file not found at $resultFile" -ForegroundColor Yellow
}

Write-Host "`n=== Done ===" -ForegroundColor Cyan

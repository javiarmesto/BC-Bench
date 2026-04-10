<#
.SYNOPSIS
    Setup infrastructure and launch BC-Bench evaluation with ALDC integration.
.DESCRIPTION
    End-to-end script that:
    1. Validates prerequisites (Docker, PowerShell modules, Python/uv, Claude Code)
    2. Installs missing dependencies
    3. Clones the target repository at the correct commit
    4. Creates and initializes a Business Central container
    5. Runs the BC-Bench evaluation with ALDC enabled

    Designed to be run on a Windows machine with Docker (Hyper-V) support.
.PARAMETER InstanceId
    Specific dataset entry to evaluate (e.g., "microsoft__BCApps-5633").
    If omitted, evaluates all entries for the given category.
.PARAMETER Category
    Evaluation category: "bug-fix" or "test-generation". Default: "bug-fix"
.PARAMETER Model
    Claude model to use. Default: "claude-sonnet-4-6"
.PARAMETER Agent
    Agent to evaluate with: "claude" or "copilot". Default: "claude"
.PARAMETER ContainerName
    Name for the BC container. Default: "bcbench"
.PARAMETER RepoPath
    Path where the target repository will be cloned. Default: .\testbed
.PARAMETER OutputDir
    Directory for evaluation results. Default: .\evaluation_results
.PARAMETER AlMcp
    Enable the AL MCP server for richer tool access. Default: $true
.PARAMETER TestRun
    If set, only evaluates 2 entries (for quick validation).
.PARAMETER SkipContainerSetup
    Skip container creation (use existing container).
.PARAMETER SkipRepoClone
    Skip repository cloning (use existing repo at RepoPath).
.PARAMETER CompareBaseline
    Run evaluation twice: once with ALDC (al-developer), once without, and compare results.
.PARAMETER CompareAll
    Run evaluation three times: baseline (no ALDC), ALDC + al-developer, ALDC + al-conductor (TDD).
    Best for test-generation category where TDD orchestration may outperform direct implementation.
.PARAMETER AldcAgent
    ALDC agent to use: "al-developer-bench" (tactical, default) or "al-conductor-bench" (TDD orchestration).
    al-conductor-bench delegates to subagents (planning, implementation, review) and enforces TDD.
    Recommended: al-developer-bench for bug-fix, al-conductor-bench for test-generation.
    Ignored when -Scenario is used.
.PARAMETER Scenario
    Run exactly one named scenario, ignoring -CompareBaseline/-CompareAll/-AldcAgent.
    Values: "baseline", "aldc-developer", "aldc-conductor".
    Use this when you want full manual control over scenario sequencing (e.g. to
    insert long cooldowns between runs to avoid the Anthropic API "overloaded_error").
.PARAMETER PauseBetweenScenarios
    Seconds to wait between scenarios in -CompareBaseline/-CompareAll modes. Default: 0.
    Useful when Anthropic returns "overloaded_error" — try 120-300 seconds.
    Ignored in single-scenario mode (no second scenario to pause before).
.EXAMPLE
    # Evaluate a single entry with ALDC
    .\Setup-ALDCEvaluation.ps1 -InstanceId "microsoft__BCApps-5633"
.EXAMPLE
    # Quick test run (2 entries)
    .\Setup-ALDCEvaluation.ps1 -TestRun
.EXAMPLE
    # Compare ALDC vs baseline (back to back)
    .\Setup-ALDCEvaluation.ps1 -InstanceId "microsoft__BCApps-5633" -CompareBaseline
.EXAMPLE
    # Compare all 3 scenarios with 3-minute cooldowns between them
    .\Setup-ALDCEvaluation.ps1 -InstanceId "microsoft__BCApps-5633" -CompareAll -PauseBetweenScenarios 180
.EXAMPLE
    # Run ONE scenario manually — lets you space runs by hand to avoid API overload
    .\Setup-ALDCEvaluation.ps1 -InstanceId "microsoft__BCApps-5633" -Scenario baseline -SkipContainerSetup -SkipRepoClone -RepoPath "C:\bcbench\testbed"
    .\Setup-ALDCEvaluation.ps1 -InstanceId "microsoft__BCApps-5633" -Scenario aldc-developer -SkipContainerSetup -SkipRepoClone -RepoPath "C:\bcbench\testbed"
    .\Setup-ALDCEvaluation.ps1 -InstanceId "microsoft__BCApps-5633" -Scenario aldc-conductor -SkipContainerSetup -SkipRepoClone -RepoPath "C:\bcbench\testbed"
.EXAMPLE
    # Evaluate with TDD orchestration (al-conductor)
    .\Setup-ALDCEvaluation.ps1 -InstanceId "microsoft__BCApps-5633" -AldcAgent "al-conductor-bench" -Category "test-generation"
.EXAMPLE
    # Use existing container and repo
    .\Setup-ALDCEvaluation.ps1 -InstanceId "microsoft__BCApps-5633" -SkipContainerSetup -SkipRepoClone -RepoPath "C:\testbed"
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$InstanceId,

    [Parameter(Mandatory = $false)]
    [ValidateSet("bug-fix", "test-generation")]
    [string]$Category = "bug-fix",

    [Parameter(Mandatory = $false)]
    [ValidateSet("claude-sonnet-4-6", "claude-opus-4-6", "claude-haiku-4-5",
        "claude-sonnet-4.5", "claude-sonnet-4.6", "claude-haiku-4.5",
        "claude-opus-4.5", "claude-opus-4.6", "claude-opus-4.6-fast",
        "gpt-5.4", "gpt-5.3-codex", "gpt-5.2-codex", "gpt-5.2", "gpt-4.1")]
    [string]$Model = "claude-sonnet-4-6",

    [Parameter(Mandatory = $false)]
    [ValidateSet("claude", "copilot")]
    [string]$Agent = "claude",

    [Parameter(Mandatory = $false)]
    [string]$ContainerName = $(if ($env:BC_CONTAINER_NAME) { $env:BC_CONTAINER_NAME } else { "bcbench" }),

    [Parameter(Mandatory = $false)]
    [string]$Username = $(if ($env:BC_CONTAINER_USERNAME) { $env:BC_CONTAINER_USERNAME } else { "admin" }),

    [Parameter(Mandatory = $false)]
    [string]$RepoPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputDir = "evaluation_results",

    [Parameter(Mandatory = $false)]
    [switch]$AlMcp = $true,

    [Parameter(Mandatory = $false)]
    [switch]$TestRun,

    [Parameter(Mandatory = $false)]
    [switch]$SkipContainerSetup,

    [Parameter(Mandatory = $false)]
    [switch]$SkipRepoClone,

    [Parameter(Mandatory = $false)]
    [switch]$CompareBaseline,

    [Parameter(Mandatory = $false)]
    [switch]$CompareAll,

    [Parameter(Mandatory = $false)]
    [ValidateSet("al-developer-bench", "al-conductor-bench")]
    [string]$AldcAgent = "al-developer-bench",

    [Parameter(Mandatory = $false)]
    [ValidateSet("baseline", "aldc-developer", "aldc-conductor")]
    [string]$Scenario,

    [Parameter(Mandatory = $false)]
    [int]$PauseBetweenScenarios = 0
)

$ErrorActionPreference = "Stop"
$ScriptRoot = $PSScriptRoot
$ProjectRoot = Split-Path $ScriptRoot -Parent

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-Step {
    param([string]$Message, [int]$Step, [int]$Total)
    $bar = "=" * 70
    Write-Host "`n$bar" -ForegroundColor Cyan
    Write-Host " [$Step/$Total] $Message" -ForegroundColor Cyan
    Write-Host "$bar`n" -ForegroundColor Cyan
}

function Write-Success { param([string]$Message) Write-Host "  [OK] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "  [!!] $Message" -ForegroundColor Yellow }
function Write-Err { param([string]$Message) Write-Host "  [FAIL] $Message" -ForegroundColor Red }
function Write-Info { param([string]$Message) Write-Host "  [..] $Message" -ForegroundColor White }

# ============================================================================
# STEP 1: VALIDATE PREREQUISITES
# ============================================================================

if ($Scenario) {
    # Manual single-scenario mode overrides compare flags
    $totalSteps = 6
}
elseif ($CompareAll) { $totalSteps = 8 }
elseif ($CompareBaseline) { $totalSteps = 7 }
else { $totalSteps = 6 }
Write-Step "Validating prerequisites" -Step 1 -Total $totalSteps

$errors = @()

# Docker
if (Get-Command docker -ErrorAction SilentlyContinue) {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker is running"
    }
    else {
        $errors += "Docker daemon is not running. Start Docker Desktop or the Docker service."
    }
}
else {
    $errors += "Docker is not installed. Install Docker Desktop with Hyper-V support."
}

# PowerShell 7+
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Success "PowerShell $($PSVersionTable.PSVersion) detected"
}
else {
    $errors += "PowerShell 7+ required. Current version: $($PSVersionTable.PSVersion)"
}

# Python / uv
if (Get-Command uv -ErrorAction SilentlyContinue) {
    Write-Success "uv $(uv --version 2>&1) detected"
}
else {
    Write-Warn "uv not found. Installing..."
    irm https://astral.sh/uv/install.ps1 | iex
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Success "uv installed successfully"
    }
    else {
        $errors += "Failed to install uv. Install manually: https://docs.astral.sh/uv/getting-started/installation/"
    }
}

# Node.js
if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Success "Node.js $(node --version 2>&1) detected"
}
else {
    $errors += "Node.js not found. Install from https://nodejs.org/"
}

# Git
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Success "Git $(git --version 2>&1) detected"
}
else {
    $errors += "Git is not installed."
}

# Claude Code (for claude agent)
if ($Agent -eq "claude") {
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCmd) {
        Write-Success "Claude Code detected at $($claudeCmd.Source)"
    }
    else {
        Write-Warn "Claude Code not found. Installing..."
        npm install -g @anthropic-ai/claude-code@2.1.69
        if (Get-Command claude -ErrorAction SilentlyContinue) {
            Write-Success "Claude Code installed"
        }
        else {
            $errors += "Failed to install Claude Code. Run: npm install -g @anthropic-ai/claude-code"
        }
    }
}

# Environment variables
if ($Agent -eq "claude") {
    if ([string]::IsNullOrEmpty($env:ANTHROPIC_API_KEY)) {
        $errors += "ANTHROPIC_API_KEY environment variable is not set."
    }
    else {
        Write-Success "ANTHROPIC_API_KEY is set"
    }
}

if ([string]::IsNullOrEmpty($env:BC_CONTAINER_PASSWORD) -and -not $SkipContainerSetup) {
    $errors += "BC_CONTAINER_PASSWORD environment variable is not set. Set it or pass credentials when prompted."
}

if ([string]::IsNullOrEmpty($env:GITHUB_TOKEN)) {
    Write-Warn "GITHUB_TOKEN is not set. Required for cloning microsoft/BCApps."
}
else {
    Write-Success "GITHUB_TOKEN is set"
}

# AL MCP tool (optional)
if ($AlMcp) {
    if (Get-Command al -ErrorAction SilentlyContinue) {
        Write-Success "AL Tool (MCP) detected"
    }
    else {
        Write-Warn "AL Tool not found. Installing..."
        dotnet tool install -g Microsoft.Dynamics.BusinessCentral.Development.Tools --version 17.0.33.55542
        $toolsPath = Join-Path $env:USERPROFILE ".dotnet\tools"
        if ($env:PATH -notlike "*$toolsPath*") {
            $env:PATH = "$toolsPath;$env:PATH"
        }
        if (Get-Command al -ErrorAction SilentlyContinue) {
            Write-Success "AL Tool installed"
        }
        else {
            Write-Warn "AL Tool installation failed. --al-mcp may not work."
        }
    }
}

# BcContainerHelper module
if (-not $SkipContainerSetup) {
    if (Get-Module -ListAvailable -Name BcContainerHelper) {
        Write-Success "BcContainerHelper module available"
    }
    else {
        Write-Warn "BcContainerHelper not found. Installing..."
        Install-Module -Name BcContainerHelper -Force -AllowClobber -AllowPrerelease -Scope CurrentUser
        if (Get-Module -ListAvailable -Name BcContainerHelper) {
            Write-Success "BcContainerHelper installed"
        }
        else {
            $errors += "Failed to install BcContainerHelper."
        }
    }
}

# Dataset
$datasetPath = Join-Path (Join-Path $ProjectRoot "dataset") "bcbench.jsonl"
if (Test-Path $datasetPath) {
    $entryCount = (Get-Content $datasetPath).Count
    Write-Success "Dataset found: $entryCount entries"
}
else {
    $errors += "Dataset not found at $datasetPath"
}

# Abort if critical errors
if ($errors.Count -gt 0) {
    Write-Host "`n" -NoNewline
    Write-Err "Prerequisites check failed:"
    foreach ($e in $errors) {
        Write-Host "    - $e" -ForegroundColor Red
    }
    Write-Host ""
    exit 1
}

Write-Success "All prerequisites validated"

# ============================================================================
# STEP 2: INSTALL PYTHON DEPENDENCIES
# ============================================================================

Write-Step "Installing Python dependencies" -Step 2 -Total $totalSteps

Push-Location $ProjectRoot
try {
    uv sync --all-groups 2>&1 | ForEach-Object { Write-Info $_ }
    Write-Success "Python dependencies installed"
}
finally {
    Pop-Location
}

# ============================================================================
# STEP 3: GET DATASET ENTRIES
# ============================================================================

Write-Step "Resolving dataset entries" -Step 3 -Total $totalSteps

$bcbenchArgs = @()
if ($InstanceId) {
    Write-Info "Single entry mode: $InstanceId"
    $entries = @($InstanceId)
}
elseif ($TestRun) {
    Write-Info "Test run mode: selecting 2 random entries"
    Push-Location $ProjectRoot
    $listOutput = uv run bcbench dataset list --category $Category --test-run 2>&1
    Pop-Location
    # Filter lines matching entry ID pattern (org__repo-number)
    $entries = $listOutput | ForEach-Object { $_.Trim().TrimStart('- ') } | Where-Object { $_ -match '^\S+__\S+-\d+$' } | Select-Object -First 2
    Write-Info "Selected entries: $($entries -join ', ')"
}
else {
    Write-Info "Full run mode: all entries for category '$Category'"
    Push-Location $ProjectRoot
    $listOutput = uv run bcbench dataset list --category $Category 2>&1
    Pop-Location
    $entries = $listOutput -replace '^\s+', '' -replace '\s+$', '' | Where-Object { $_ -match '^\S+__\S+-\d+$' }
    Write-Info "Found $($entries.Count) entries"
}

if ($entries.Count -eq 0) {
    Write-Err "No dataset entries found."
    exit 1
}

# ============================================================================
# STEP 4: SETUP REPOSITORY
# ============================================================================

Write-Step "Setting up target repository" -Step 4 -Total $totalSteps

if (-not $RepoPath) {
    $RepoPath = Join-Path (Get-Location) "testbed"
}

if ($SkipRepoClone) {
    if (Test-Path $RepoPath) {
        Write-Success "Using existing repository at $RepoPath"
    }
    else {
        Write-Err "Repository not found at $RepoPath (--SkipRepoClone was set)"
        exit 1
    }
}
else {
    if (Test-Path $RepoPath) {
        Write-Warn "Removing existing testbed at $RepoPath"

        # Kill processes that may hold file handles
        foreach ($proc in @("claude", "node", "copilot", "gh", "git")) {
            taskkill /F /IM "$proc.exe" 2>$null | Out-Null
        }
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
        Start-Sleep -Seconds 3

        $removed = $false
        # Strategy 1: PowerShell Remove-Item
        try {
            Remove-Item -Path $RepoPath -Recurse -Force -ErrorAction Stop
            $removed = $true
        }
        catch {
            Write-Warn "Remove-Item failed: $_"
        }

        # Strategy 2: cmd.exe rd /s /q (bypasses PowerShell handle tracking)
        if (-not $removed -and (Test-Path $RepoPath)) {
            Write-Warn "Trying cmd /c rd /s /q..."
            cmd /c "rd /s /q `"$RepoPath`"" 2>$null
            Start-Sleep -Seconds 2
            if (-not (Test-Path $RepoPath)) { $removed = $true }
        }

        # Strategy 3: Rename out of the way and delete in background
        if (-not $removed -and (Test-Path $RepoPath)) {
            $tombstone = "${RepoPath}_delete_$(Get-Random)"
            Write-Warn "Renaming testbed to $tombstone and deleting in background..."
            try {
                Rename-Item $RepoPath $tombstone -Force
                Start-Job -ScriptBlock { param($p) cmd /c "rd /s /q `"$p`"" } -ArgumentList $tombstone | Out-Null
                $removed = $true
            }
            catch {
                Write-Warn "Rename also failed: $_"
            }
        }

        if (-not $removed -and (Test-Path $RepoPath)) {
            throw "Cannot remove testbed at $RepoPath — a process is holding a lock. Check with: handle.exe $RepoPath"
        }
    }

    # Import BC-Bench utilities for clone function
    Import-Module "$ScriptRoot\BCBenchUtils.psm1" -Force -DisableNameChecking
    Import-Module "$ScriptRoot\DatasetEntry.psm1" -Force -DisableNameChecking

    # Read the first entry to determine repo and commit
    $firstEntry = Get-Content $datasetPath | ForEach-Object { $_ | ConvertFrom-Json } |
    Where-Object { $_.instance_id -eq $entries[0] } | Select-Object -First 1

    if (-not $firstEntry) {
        Write-Err "Entry '$($entries[0])' not found in dataset"
        exit 1
    }

    $repoName = $firstEntry.repo
    $commitSha = $firstEntry.base_commit

    Write-Info "Cloning $repoName at commit $commitSha"
    Write-Info "Destination: $RepoPath"

    # Determine clone info
    $repoParts = $repoName -split '/'
    $isGitHub = $repoParts[0].ToLower() -ne 'microsoftinternal'

    if ($isGitHub) {
        $cloneUrl = "https://github.com/$repoName.git"
        $token = $env:GITHUB_TOKEN
        $sparseCheckoutPaths = @()
    }
    else {
        $cloneUrl = 'https://dynamicssmb2.visualstudio.com/Dynamics%20SMB/_git/NAV'
        $token = $env:ADO_TOKEN
        $sparseCheckoutPaths = @('App/Apps', 'App/Layers')
    }

    if ([string]::IsNullOrEmpty($token)) {
        Write-Err "Authentication token not set. Set GITHUB_TOKEN or ADO_TOKEN."
        exit 1
    }

    Invoke-GitCloneWithRetry `
        -RepoUrl $cloneUrl `
        -Token $token `
        -ClonePath $RepoPath `
        -CommitSha $commitSha `
        -SparseCheckoutPaths $sparseCheckoutPaths

    Write-Success "Repository cloned at $RepoPath"
}

# ============================================================================
# STEP 5: SETUP BC CONTAINER
# ============================================================================

Write-Step "Setting up Business Central container" -Step 5 -Total $totalSteps

if ($SkipContainerSetup) {
    # Verify container exists
    $containerExists = docker ps -q -f name="$ContainerName" 2>$null
    if ($containerExists) {
        Write-Success "Using existing container '$ContainerName'"
    }
    else {
        Write-Err "Container '$ContainerName' not found (--SkipContainerSetup was set)"
        exit 1
    }
}
else {
    # Check if container already exists
    $containerExists = docker ps -aq -f name="$ContainerName" 2>$null
    if ($containerExists) {
        Write-Warn "Container '$ContainerName' already exists. Removing..."
        docker rm -f $ContainerName 2>$null
    }

    # Use the Setup-ContainerAndRepository.ps1 script directly
    Write-Info "Creating BC container '$ContainerName'..."
    Write-Info "This may take 15-30 minutes on first run (downloading BC artifacts)"

    Push-Location $ScriptRoot
    try {
        $setupArgs = @{
            InstanceId    = $entries[0]
            ContainerName = $ContainerName
            Username      = $Username
            RepoPath      = $RepoPath
        }

        # The setup script handles version detection from the dataset entry
        & "$ScriptRoot\Setup-ContainerAndRepository.ps1" @setupArgs
        Write-Success "BC container '$ContainerName' created and initialized"
    }
    finally {
        Pop-Location
    }
}

# ============================================================================
# EVALUATION HELPER FUNCTION
# ============================================================================

$configPath = Join-Path $ProjectRoot "src\bcbench\agent\shared\config.yaml"
$configOriginal = Get-Content $configPath -Raw
$password = $env:BC_CONTAINER_PASSWORD
$totalEntries = $entries.Count

# Tracks results per scenario for final summary
$scenarioResults = @{}

function Invoke-EvaluationScenario {
    <#
    .SYNOPSIS
        Run BC-Bench evaluation with a specific config.yaml configuration.
    .PARAMETER ScenarioName
        Display name for this scenario (e.g., "ALDC + al-developer")
    .PARAMETER ScenarioTag
        Short tag for output directory suffix (e.g., "aldc_developer")
    .PARAMETER InstructionsEnabled
        Enable/disable ALDC instructions
    .PARAMETER SkillsEnabled
        Enable/disable ALDC skills
    .PARAMETER AgentsEnabled
        Enable/disable ALDC custom agents
    .PARAMETER AgentName
        ALDC agent name (e.g., "al-developer", "al-conductor")
    #>
    param(
        [string]$ScenarioName,
        [string]$ScenarioTag,
        [bool]$InstructionsEnabled,
        [bool]$SkillsEnabled,
        [bool]$AgentsEnabled,
        [string]$AgentName = "al-developer"
    )

    $scenarioOutputDir = "${OutputDir}_${ScenarioTag}"

    # Build config content with the desired settings
    $instrValue = if ($InstructionsEnabled) { "true" } else { "false" }
    $skillsValue = if ($SkillsEnabled) { "true" } else { "false" }
    $agentsValue = if ($AgentsEnabled) { "true" } else { "false" }

    $scenarioConfig = $configOriginal `
        -replace '(instructions:\s*\n\s*enabled:\s*)\S+', "`${1}$instrValue" `
        -replace '(skills:\s*\n\s*enabled:\s*)\S+', "`${1}$skillsValue" `
        -replace '(agents:\s*\n\s*enabled:\s*)\S+', "`${1}$agentsValue" `
        -replace '(agents:\s*\n\s*enabled:\s*\S+\s*\n\s*name:\s*)\S+', "`${1}$AgentName"
    $scenarioConfig | Set-Content $configPath -Encoding UTF8

    Write-Info "Scenario:  $ScenarioName"
    Write-Info "ALDC:      instructions=$InstructionsEnabled, skills=$SkillsEnabled, agents=$AgentsEnabled"
    if ($AgentsEnabled) { Write-Info "Agent:     $AgentName" }
    Write-Info "Output:    $scenarioOutputDir"
    Write-Host ""

    $scenarioSuccess = 0
    $scenarioFail = 0

    foreach ($entry in $script:entries) {
        $idx = [array]::IndexOf($script:entries, $entry) + 1
        Write-Info "[$idx/$script:totalEntries] $($ScenarioName): $entry"

        $evalArgs = @(
            "run", "bcbench", "evaluate", $script:Agent, $entry,
            "--model", $script:Model,
            "--category", $script:Category,
            "--repo-path", $script:RepoPath,
            "--output-dir", $scenarioOutputDir,
            "--container-name", $script:ContainerName,
            "--username", $script:Username,
            "--password", $script:password
        )
        if ($script:AlMcp) {
            $evalArgs += "--al-mcp"
        }

        Push-Location $script:ProjectRoot
        try {
            $startTime = Get-Date
            uv @evalArgs 2>&1 | ForEach-Object { Write-Host "    $_" }

            if ($LASTEXITCODE -eq 0) {
                $elapsed = (Get-Date) - $startTime
                Write-Success "$entry completed in $([math]::Round($elapsed.TotalMinutes, 1)) minutes"
                $scenarioSuccess++
            }
            else {
                Write-Err "$entry failed (exit code: $LASTEXITCODE)"
                $scenarioFail++
            }
        }
        catch {
            Write-Err "$entry error: $($_.Exception.Message)"
            $scenarioFail++
        }
        finally {
            Pop-Location
        }
    }

    Write-Host ""
    Write-Info "$ScenarioName Results: $scenarioSuccess passed, $scenarioFail failed out of $script:totalEntries"

    # Store results for final summary
    $script:scenarioResults[$ScenarioName] = @{
        Success   = $scenarioSuccess
        Fail      = $scenarioFail
        OutputDir = $scenarioOutputDir
    }
}

# ============================================================================
# STEPS 6..8: RUN SCENARIOS
#   - manual mode via -Scenario: runs exactly one named scenario
#   - comparison mode via -CompareBaseline / -CompareAll: runs 2 or 3 scenarios
#     back-to-back, with optional -PauseBetweenScenarios cooldown between them
#     (useful when hitting Anthropic API "overloaded_error")
# ============================================================================

Write-Host "`nAgent:     $Agent" -ForegroundColor Cyan
Write-Host "Model:     $Model" -ForegroundColor Cyan
Write-Host "Category:  $Category" -ForegroundColor Cyan
Write-Host "AL MCP:    $AlMcp" -ForegroundColor Cyan
Write-Host "Entries:   $($entries.Count)" -ForegroundColor Cyan
if ($PauseBetweenScenarios -gt 0) {
    Write-Host "Pause:     $PauseBetweenScenarios seconds between scenarios" -ForegroundColor Cyan
}
Write-Host ""

# Build the list of scenarios to run
$scenariosToRun = @()

if ($Scenario) {
    # ---- Manual single-scenario mode ----
    switch ($Scenario) {
        "baseline" {
            $scenariosToRun += [pscustomobject]@{
                Name      = "Baseline (no ALDC)"
                Tag       = "baseline"
                Instr     = $false
                Skills    = $false
                Agents    = $false
                AgentName = "al-developer-bench"  # placeholder — ignored when Agents=false
            }
        }
        "aldc-developer" {
            $scenariosToRun += [pscustomobject]@{
                Name      = "ALDC + al-developer-bench"
                Tag       = "aldc_al_developer_bench"
                Instr     = $true
                Skills    = $true
                Agents    = $true
                AgentName = "al-developer-bench"
            }
        }
        "aldc-conductor" {
            $scenariosToRun += [pscustomobject]@{
                Name      = "ALDC + al-conductor-bench"
                Tag       = "aldc_al_conductor_bench"
                Instr     = $true
                Skills    = $true
                Agents    = $true
                AgentName = "al-conductor-bench"
            }
        }
    }
}
else {
    # ---- Comparison mode: primary + optional baseline + optional second agent ----
    $primaryTag = if ($CompareBaseline -or $CompareAll) {
        "aldc_$($AldcAgent -replace '-','_')"
    }
    else {
        $OutputDir -replace '.*[/\\]', ''
    }

    $scenariosToRun += [pscustomobject]@{
        Name      = "ALDC + $AldcAgent"
        Tag       = $primaryTag
        Instr     = $true
        Skills    = $true
        Agents    = $true
        AgentName = $AldcAgent
    }

    if ($CompareBaseline -or $CompareAll) {
        $scenariosToRun += [pscustomobject]@{
            Name      = "Baseline (no ALDC)"
            Tag       = "baseline"
            Instr     = $false
            Skills    = $false
            Agents    = $false
            AgentName = "al-developer-bench"  # placeholder
        }
    }

    if ($CompareAll) {
        # Primary is al-developer-bench -> second is al-conductor-bench, and vice versa
        $tddAgent = if ($AldcAgent -eq "al-developer-bench") { "al-conductor-bench" } else { "al-developer-bench" }
        $tddLabel = if ($tddAgent -eq "al-conductor-bench") { "TDD Orchestration" } else { "Direct Implementation" }

        $scenariosToRun += [pscustomobject]@{
            Name      = "ALDC + $tddAgent ($tddLabel)"
            Tag       = "aldc_$($tddAgent -replace '-','_')"
            Instr     = $true
            Skills    = $true
            Agents    = $true
            AgentName = $tddAgent
        }
    }
}

# Run each scenario sequentially, with optional cooldown between
$scenarioIndex = 0
foreach ($sc in $scenariosToRun) {
    $scenarioIndex++
    $stepNumber = 5 + $scenarioIndex

    # Cooldown before 2nd/3rd scenarios (not before the first)
    if ($scenarioIndex -gt 1 -and $PauseBetweenScenarios -gt 0) {
        Write-Host ""
        Write-Info "Cooling down $PauseBetweenScenarios seconds before next scenario to avoid API rate limits..."
        Start-Sleep -Seconds $PauseBetweenScenarios
        Write-Info "Cooldown complete."
    }

    Write-Step "[$scenarioIndex/$($scenariosToRun.Count)] $($sc.Name)" -Step $stepNumber -Total $totalSteps

    Invoke-EvaluationScenario `
        -ScenarioName $sc.Name `
        -ScenarioTag $sc.Tag `
        -InstructionsEnabled $sc.Instr `
        -SkillsEnabled $sc.Skills `
        -AgentsEnabled $sc.Agents `
        -AgentName $sc.AgentName
}

# ============================================================================
# RESTORE ORIGINAL CONFIG
# ============================================================================

# Always restore the original config so subsequent runs start from a known state.
# Invoke-EvaluationScenario mutates config.yaml in place, and any non-trivial scenario
# (including single-scenario manual mode) leaves it modified.
Write-Info "Restoring original config.yaml..."
$configOriginal | Set-Content $configPath -Encoding UTF8
Write-Success "Config restored"

# ============================================================================
# FINAL SUMMARY
# ============================================================================

$bar = "=" * 70
Write-Host "`n$bar" -ForegroundColor Green
Write-Host " EVALUATION COMPLETE" -ForegroundColor Green
Write-Host "$bar" -ForegroundColor Green
Write-Host ""
Write-Host "  Agent:     $Agent" -ForegroundColor White
Write-Host "  Model:     $Model" -ForegroundColor White
Write-Host "  Category:  $Category" -ForegroundColor White
Write-Host "  AL MCP:    $AlMcp" -ForegroundColor White
Write-Host "  Entries:   $totalEntries" -ForegroundColor White
Write-Host ""

if ($scenarioResults.Count -gt 1) {
    Write-Host "  SCENARIO COMPARISON:" -ForegroundColor Magenta
    Write-Host "  $("-" * 60)" -ForegroundColor Magenta
    foreach ($scenario in $scenarioResults.GetEnumerator() | Sort-Object { $_.Value.Success } -Descending) {
        $s = $scenario.Value
        $pct = if ($totalEntries -gt 0) { [math]::Round(($s.Success / $totalEntries) * 100, 1) } else { 0 }
        $color = if ($s.Success -eq ($scenarioResults.Values | Measure-Object -Property Success -Maximum).Maximum) { "Green" } else { "Yellow" }
        Write-Host "    $($scenario.Key):" -ForegroundColor White -NoNewline
        Write-Host " $($s.Success)/$totalEntries resolved ($pct%)" -ForegroundColor $color
        Write-Host "      -> $($s.OutputDir)" -ForegroundColor DarkGray
    }
    Write-Host ""

    # Aggregate all results
    Write-Info "Aggregating results..."
    Push-Location $ProjectRoot
    foreach ($scenario in $scenarioResults.GetEnumerator()) {
        $dir = $scenario.Value.OutputDir
        if (Test-Path $dir) {
            uv run bcbench result aggregate --input-dir $dir 2>&1 | ForEach-Object { Write-Host "    $_" }
        }
    }
    Pop-Location
}
else {
    $primary = $scenarioResults.GetEnumerator() | Select-Object -First 1
    if ($primary) {
        $s = $primary.Value
        Write-Host "  ALDC:      $AldcAgent" -ForegroundColor White
        Write-Host "  Resolved:  $($s.Success)/$totalEntries" -ForegroundColor White
        Write-Host "  Results:   $($s.OutputDir)" -ForegroundColor White
    }
}

Write-Host ""
if (-not $CompareBaseline -and -not $CompareAll) {
    Write-Host "  To compare scenarios, re-run with:" -ForegroundColor Cyan
    Write-Host "    -CompareBaseline   (2 scenarios: ALDC vs no-ALDC)" -ForegroundColor Cyan
    Write-Host "    -CompareAll        (3 scenarios: baseline vs al-developer vs al-conductor)" -ForegroundColor Cyan
}
Write-Host ""
Write-Host "$bar`n" -ForegroundColor Green

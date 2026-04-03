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
    Run evaluation twice: once with ALDC, once without, and compare results.
.EXAMPLE
    # Evaluate a single entry with ALDC
    .\Setup-ALDCEvaluation.ps1 -InstanceId "microsoft__BCApps-5633"
.EXAMPLE
    # Quick test run (2 entries)
    .\Setup-ALDCEvaluation.ps1 -TestRun
.EXAMPLE
    # Compare ALDC vs baseline
    .\Setup-ALDCEvaluation.ps1 -InstanceId "microsoft__BCApps-5633" -CompareBaseline
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
    [ValidateSet("claude-sonnet-4-6", "claude-opus-4-6", "claude-haiku-4-5")]
    [string]$Model = "claude-sonnet-4-6",

    [Parameter(Mandatory = $false)]
    [ValidateSet("claude", "copilot")]
    [string]$Agent = "claude",

    [Parameter(Mandatory = $false)]
    [string]$ContainerName = $env:BC_CONTAINER_NAME ?? "bcbench",

    [Parameter(Mandatory = $false)]
    [string]$Username = $env:BC_CONTAINER_USERNAME ?? "admin",

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
    [switch]$CompareBaseline
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

$totalSteps = if ($CompareBaseline) { 7 } else { 6 }
Write-Step "Validating prerequisites" -Step 1 -Total $totalSteps

$errors = @()

# Docker
if (Get-Command docker -ErrorAction SilentlyContinue) {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker is running"
    } else {
        $errors += "Docker daemon is not running. Start Docker Desktop or the Docker service."
    }
} else {
    $errors += "Docker is not installed. Install Docker Desktop with Hyper-V support."
}

# PowerShell 7+
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Success "PowerShell $($PSVersionTable.PSVersion) detected"
} else {
    $errors += "PowerShell 7+ required. Current version: $($PSVersionTable.PSVersion)"
}

# Python / uv
if (Get-Command uv -ErrorAction SilentlyContinue) {
    Write-Success "uv $(uv --version 2>&1) detected"
} else {
    Write-Warn "uv not found. Installing..."
    irm https://astral.sh/uv/install.ps1 | iex
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Success "uv installed successfully"
    } else {
        $errors += "Failed to install uv. Install manually: https://docs.astral.sh/uv/getting-started/installation/"
    }
}

# Node.js
if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Success "Node.js $(node --version 2>&1) detected"
} else {
    $errors += "Node.js not found. Install from https://nodejs.org/"
}

# Git
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Success "Git $(git --version 2>&1) detected"
} else {
    $errors += "Git is not installed."
}

# Claude Code (for claude agent)
if ($Agent -eq "claude") {
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCmd) {
        Write-Success "Claude Code detected at $($claudeCmd.Source)"
    } else {
        Write-Warn "Claude Code not found. Installing..."
        npm install -g @anthropic-ai/claude-code@2.1.69
        if (Get-Command claude -ErrorAction SilentlyContinue) {
            Write-Success "Claude Code installed"
        } else {
            $errors += "Failed to install Claude Code. Run: npm install -g @anthropic-ai/claude-code"
        }
    }
}

# Environment variables
if ($Agent -eq "claude") {
    if ([string]::IsNullOrEmpty($env:ANTHROPIC_API_KEY)) {
        $errors += "ANTHROPIC_API_KEY environment variable is not set."
    } else {
        Write-Success "ANTHROPIC_API_KEY is set"
    }
}

if ([string]::IsNullOrEmpty($env:BC_CONTAINER_PASSWORD) -and -not $SkipContainerSetup) {
    $errors += "BC_CONTAINER_PASSWORD environment variable is not set. Set it or pass credentials when prompted."
}

if ([string]::IsNullOrEmpty($env:GITHUB_TOKEN)) {
    Write-Warn "GITHUB_TOKEN is not set. Required for cloning microsoft/BCApps."
} else {
    Write-Success "GITHUB_TOKEN is set"
}

# AL MCP tool (optional)
if ($AlMcp) {
    if (Get-Command al -ErrorAction SilentlyContinue) {
        Write-Success "AL Tool (MCP) detected"
    } else {
        Write-Warn "AL Tool not found. Installing..."
        dotnet tool install -g Microsoft.Dynamics.BusinessCentral.Development.Tools --version 17.0.33.55542
        $toolsPath = Join-Path $env:USERPROFILE ".dotnet\tools"
        if ($env:PATH -notlike "*$toolsPath*") {
            $env:PATH = "$toolsPath;$env:PATH"
        }
        if (Get-Command al -ErrorAction SilentlyContinue) {
            Write-Success "AL Tool installed"
        } else {
            Write-Warn "AL Tool installation failed. --al-mcp may not work."
        }
    }
}

# BcContainerHelper module
if (-not $SkipContainerSetup) {
    if (Get-Module -ListAvailable -Name BcContainerHelper) {
        Write-Success "BcContainerHelper module available"
    } else {
        Write-Warn "BcContainerHelper not found. Installing..."
        Install-Module -Name BcContainerHelper -Force -AllowClobber -AllowPrerelease -Scope CurrentUser
        if (Get-Module -ListAvailable -Name BcContainerHelper) {
            Write-Success "BcContainerHelper installed"
        } else {
            $errors += "Failed to install BcContainerHelper."
        }
    }
}

# Dataset
$datasetPath = Join-Path $ProjectRoot "dataset" "bcbench.jsonl"
if (Test-Path $datasetPath) {
    $entryCount = (Get-Content $datasetPath).Count
    Write-Success "Dataset found: $entryCount entries"
} else {
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
} finally {
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
} elseif ($TestRun) {
    Write-Info "Test run mode: selecting 2 random entries"
    Push-Location $ProjectRoot
    $listOutput = uv run bcbench dataset list --category $Category 2>&1
    Pop-Location
    # Take first 2 entries
    $entries = ($listOutput | Select-Object -First 2) -replace '^\s+', '' -replace '\s+$', ''
    Write-Info "Selected entries: $($entries -join ', ')"
} else {
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
    } else {
        Write-Err "Repository not found at $RepoPath (--SkipRepoClone was set)"
        exit 1
    }
} else {
    if (Test-Path $RepoPath) {
        Write-Warn "Removing existing testbed at $RepoPath"
        Remove-Item -Path $RepoPath -Recurse -Force
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
    } else {
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
    } else {
        Write-Err "Container '$ContainerName' not found (--SkipContainerSetup was set)"
        exit 1
    }
} else {
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
    } finally {
        Pop-Location
    }
}

# ============================================================================
# STEP 6: RUN EVALUATION WITH ALDC
# ============================================================================

Write-Step "Running evaluation with ALDC enabled" -Step 6 -Total $totalSteps

$password = $env:BC_CONTAINER_PASSWORD
$aldcOutputDir = if ($CompareBaseline) { "${OutputDir}_aldc" } else { $OutputDir }

Write-Info "Agent:     $Agent"
Write-Info "Model:     $Model"
Write-Info "Category:  $Category"
Write-Info "AL MCP:    $AlMcp"
Write-Info "Entries:   $($entries.Count)"
Write-Info "Output:    $aldcOutputDir"
Write-Info "ALDC:      ENABLED (instructions + skills + agents)"
Write-Host ""

$successCount = 0
$failCount = 0
$totalEntries = $entries.Count

foreach ($entry in $entries) {
    $idx = [array]::IndexOf($entries, $entry) + 1
    Write-Info "[$idx/$totalEntries] Evaluating: $entry"

    $evalArgs = @(
        "run", "bcbench", "evaluate", $Agent, $entry,
        "--model", $Model,
        "--category", $Category,
        "--repo-path", $RepoPath,
        "--output-dir", $aldcOutputDir,
        "--container-name", $ContainerName,
        "--username", $Username,
        "--password", $password
    )
    if ($AlMcp) {
        $evalArgs += "--al-mcp"
    }

    Push-Location $ProjectRoot
    try {
        $startTime = Get-Date
        uv @evalArgs 2>&1 | ForEach-Object { Write-Host "    $_" }

        if ($LASTEXITCODE -eq 0) {
            $elapsed = (Get-Date) - $startTime
            Write-Success "$entry completed in $([math]::Round($elapsed.TotalMinutes, 1)) minutes"
            $successCount++
        } else {
            Write-Err "$entry failed (exit code: $LASTEXITCODE)"
            $failCount++
        }
    } catch {
        Write-Err "$entry error: $($_.Exception.Message)"
        $failCount++
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Info "ALDC Results: $successCount passed, $failCount failed out of $totalEntries"

# ============================================================================
# STEP 7 (optional): RUN BASELINE COMPARISON (without ALDC)
# ============================================================================

if ($CompareBaseline) {
    Write-Step "Running baseline evaluation (WITHOUT ALDC)" -Step 7 -Total $totalSteps

    $baselineOutputDir = "${OutputDir}_baseline"
    $configPath = Join-Path $ProjectRoot "src" "bcbench" "agent" "shared" "config.yaml"

    # Read current config
    $configContent = Get-Content $configPath -Raw

    # Disable ALDC in config
    Write-Info "Temporarily disabling ALDC in config.yaml..."
    $baselineConfig = $configContent `
        -replace '(instructions:\s*\n\s*enabled:\s*)true', '${1}false' `
        -replace '(skills:\s*\n\s*enabled:\s*)true', '${1}false' `
        -replace '(agents:\s*\n\s*enabled:\s*)true', '${1}false'
    $baselineConfig | Set-Content $configPath -Encoding UTF8

    Write-Info "ALDC:      DISABLED (baseline comparison)"
    Write-Info "Output:    $baselineOutputDir"
    Write-Host ""

    $baselineSuccess = 0
    $baselineFail = 0

    foreach ($entry in $entries) {
        $idx = [array]::IndexOf($entries, $entry) + 1
        Write-Info "[$idx/$totalEntries] Baseline: $entry"

        $evalArgs = @(
            "run", "bcbench", "evaluate", $Agent, $entry,
            "--model", $Model,
            "--category", $Category,
            "--repo-path", $RepoPath,
            "--output-dir", $baselineOutputDir,
            "--container-name", $ContainerName,
            "--username", $Username,
            "--password", $password
        )
        if ($AlMcp) {
            $evalArgs += "--al-mcp"
        }

        Push-Location $ProjectRoot
        try {
            uv @evalArgs 2>&1 | ForEach-Object { Write-Host "    $_" }
            if ($LASTEXITCODE -eq 0) {
                Write-Success "$entry baseline completed"
                $baselineSuccess++
            } else {
                Write-Err "$entry baseline failed"
                $baselineFail++
            }
        } catch {
            Write-Err "$entry baseline error: $($_.Exception.Message)"
            $baselineFail++
        } finally {
            Pop-Location
        }
    }

    # Restore ALDC config
    Write-Info "Restoring ALDC config..."
    $configContent | Set-Content $configPath -Encoding UTF8

    # Print comparison summary
    $bar = "=" * 70
    Write-Host "`n$bar" -ForegroundColor Magenta
    Write-Host " COMPARISON SUMMARY" -ForegroundColor Magenta
    Write-Host "$bar" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  WITH ALDC:    $successCount / $totalEntries resolved" -ForegroundColor Green
    Write-Host "  WITHOUT ALDC: $baselineSuccess / $totalEntries resolved" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  ALDC results:     $aldcOutputDir" -ForegroundColor White
    Write-Host "  Baseline results: $baselineOutputDir" -ForegroundColor White
    Write-Host ""

    # Aggregate results
    Write-Info "Aggregating results..."
    Push-Location $ProjectRoot
    uv run bcbench result aggregate --input-dir $aldcOutputDir 2>&1 | ForEach-Object { Write-Host "    $_" }
    uv run bcbench result aggregate --input-dir $baselineOutputDir 2>&1 | ForEach-Object { Write-Host "    $_" }
    Pop-Location

    Write-Host "$bar`n" -ForegroundColor Magenta
}

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
Write-Host "  ALDC:      Enabled" -ForegroundColor White
Write-Host "  Entries:   $totalEntries ($successCount passed, $failCount failed)" -ForegroundColor White
Write-Host "  Results:   $(Resolve-Path $aldcOutputDir -ErrorAction SilentlyContinue ?? $aldcOutputDir)" -ForegroundColor White
Write-Host ""

if (-not $CompareBaseline) {
    Write-Host "  To compare with baseline, re-run with -CompareBaseline" -ForegroundColor Cyan
}

Write-Host "  To aggregate results:" -ForegroundColor Cyan
Write-Host "    uv run bcbench result aggregate --input-dir $aldcOutputDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "$bar`n" -ForegroundColor Green

<#
.SYNOPSIS
    Phase 2: Install all software after reboot. Run AFTER Setup-VM-Phase1.ps1.
.DESCRIPTION
    Installs Docker, PowerShell 7, Git, uv (Python), Node.js, Claude Code,
    BcContainerHelper, and AL Tool on a Windows Server 2022 VM.
.PARAMETER AnthropicApiKey
    Anthropic API key for Claude Code.
.PARAMETER GitHubToken
    GitHub personal access token (for cloning microsoft/BCApps).
.PARAMETER ContainerPassword
    Password for the BC container admin user.
.EXAMPLE
    .\Setup-VM-Phase2.ps1 -AnthropicApiKey "sk-ant-..." -GitHubToken "ghp_..." -ContainerPassword "BcBench2026!"
#>

#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory = $true)]
    [string]$AnthropicApiKey,

    [Parameter(Mandatory = $true)]
    [string]$GitHubToken,

    [Parameter(Mandatory = $false)]
    [string]$ContainerPassword = "BcBench2026!",

    [Parameter(Mandatory = $false)]
    [string]$ContainerName = "bcbench",

    [Parameter(Mandatory = $false)]
    [string]$ContainerUsername = "admin",

    [Parameter(Mandatory = $false)]
    [string]$Branch = "claude/explain-repo-usage-2rL3g"
)

$ErrorActionPreference = "Stop"

function Write-Step { param([string]$Msg, [int]$N, [int]$Total) Write-Host "`n[$N/$Total] $Msg" -ForegroundColor Yellow }
function Write-Ok { param([string]$Msg) Write-Host "  OK: $Msg" -ForegroundColor Green }
function Write-Skip { param([string]$Msg) Write-Host "  SKIP: $Msg" -ForegroundColor DarkGray }

$totalSteps = 14

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " BC-Bench VM Setup — Phase 2 (software)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# ---- 1. Verify Hyper-V ----
Write-Step "Verifying Hyper-V" 1 $totalSteps
$hv = Get-WindowsFeature -Name Hyper-V
if ($hv.Installed) { Write-Ok "Hyper-V is installed" }
else { throw "Hyper-V not installed. Run Setup-VM-Phase1.ps1 first and reboot." }

# ---- 2. Docker ----
Write-Step "Installing Docker" 2 $totalSteps
if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Skip "Docker already installed"
} else {
    Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
    Install-Package -Name docker -ProviderName DockerMsftProvider -Force
    Start-Service docker
}
# Verify
docker info | Select-String "Server Version"
Write-Ok "Docker running"

# ---- 3. PowerShell 7 ----
Write-Step "Installing PowerShell 7" 3 $totalSteps
if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    Write-Skip "PowerShell 7 already installed: $(pwsh --version)"
} else {
    $pwshUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.1/PowerShell-7.5.1-win-x64.msi"
    $pwshMsi = "$env:TEMP\pwsh.msi"
    Invoke-WebRequest -Uri $pwshUrl -OutFile $pwshMsi -UseBasicParsing
    Start-Process msiexec.exe -ArgumentList "/i `"$pwshMsi`" /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1" -Wait
    # Refresh PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    Write-Ok "PowerShell 7 installed"
}

# ---- 4. Git ----
Write-Step "Installing Git" 4 $totalSteps
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Skip "Git already installed: $(git --version)"
} else {
    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/Git-2.47.1-64-bit.exe"
    $gitExe = "$env:TEMP\git-installer.exe"
    Invoke-WebRequest -Uri $gitUrl -OutFile $gitExe -UseBasicParsing
    Start-Process $gitExe -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /COMPONENTS=`"icons,ext\reg\shellhere,assoc,assoc_sh`"" -Wait
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    Write-Ok "Git installed"
}

# ---- 5. uv (Python) ----
Write-Step "Installing uv + Python 3.13" 5 $totalSteps
if (Get-Command uv -ErrorAction SilentlyContinue) {
    Write-Skip "uv already installed: $(uv --version)"
} else {
    irm https://astral.sh/uv/install.ps1 | iex
    $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
}
uv python install 3.13
Write-Ok "uv + Python 3.13 ready"

# ---- 6. Node.js ----
Write-Step "Installing Node.js" 6 $totalSteps
if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Skip "Node.js already installed: $(node --version)"
} else {
    $nodeUrl = "https://nodejs.org/dist/v22.15.0/node-v22.15.0-x64.msi"
    $nodeMsi = "$env:TEMP\node.msi"
    Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeMsi -UseBasicParsing
    Start-Process msiexec.exe -ArgumentList "/i `"$nodeMsi`" /quiet" -Wait
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    Write-Ok "Node.js installed: $(node --version)"
}

# ---- 7. Claude Code ----
Write-Step "Installing Claude Code" 7 $totalSteps
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Skip "Claude Code already installed"
} else {
    npm install -g @anthropic-ai/claude-code@2.1.69
    Write-Ok "Claude Code 2.1.69 installed"
}

# ---- 8. GitHub Copilot CLI ----
Write-Step "Installing GitHub Copilot CLI" 8 $totalSteps
$copilotCmd = Get-Command copilot.cmd -ErrorAction SilentlyContinue
if (-not $copilotCmd) { $copilotCmd = Get-Command copilot -ErrorAction SilentlyContinue }
if ($copilotCmd) {
    Write-Skip "Copilot CLI already installed at $($copilotCmd.Source)"
} else {
    npm install -g @github/copilot
    Write-Ok "Copilot CLI installed"
    Write-Host "  NOTE: Run 'copilot auth login' interactively after this script finishes." -ForegroundColor Yellow
    Write-Host "        Required for any -Agent copilot evaluation runs." -ForegroundColor Yellow
}

# ---- 9. BcContainerHelper ----
Write-Step "Installing BcContainerHelper" 9 $totalSteps
if (Get-Module -ListAvailable -Name BcContainerHelper) {
    Write-Skip "BcContainerHelper already installed"
} else {
    Install-Module -Name BcContainerHelper -Force -AllowClobber -AllowPrerelease -Scope CurrentUser
    Write-Ok "BcContainerHelper installed"
}

# ---- 10. AL Tool (for AL MCP server) ----
Write-Step "Installing AL Tool (.NET tool)" 10 $totalSteps
if (Get-Command al -ErrorAction SilentlyContinue) {
    Write-Skip "AL Tool already installed"
} else {
    dotnet tool install -g Microsoft.Dynamics.BusinessCentral.Development.Tools --version 17.0.33.55542
    $toolsPath = Join-Path $env:USERPROFILE ".dotnet\tools"
    if ($env:PATH -notlike "*$toolsPath*") {
        $env:PATH = "$toolsPath;$env:PATH"
        [Environment]::SetEnvironmentVariable("PATH", "$toolsPath;" + [Environment]::GetEnvironmentVariable("PATH", "User"), "User")
    }
    Write-Ok "AL Tool installed"
}

# ---- 11. Environment variables ----
Write-Step "Configuring environment variables" 11 $totalSteps
$envVars = @{
    "ANTHROPIC_API_KEY"     = $AnthropicApiKey
    "GITHUB_TOKEN"          = $GitHubToken
    "BC_CONTAINER_PASSWORD" = $ContainerPassword
    "BC_CONTAINER_NAME"     = $ContainerName
    "BC_CONTAINER_USERNAME" = $ContainerUsername
}
foreach ($kv in $envVars.GetEnumerator()) {
    [Environment]::SetEnvironmentVariable($kv.Key, $kv.Value, "User")
    Set-Item -Path "env:$($kv.Key)" -Value $kv.Value
}
Write-Ok "Environment variables set (ANTHROPIC_API_KEY, GITHUB_TOKEN, BC_CONTAINER_*)"

# ---- 12. Clone BC-Bench ----
Write-Step "Cloning BC-Bench repository" 12 $totalSteps
$repoPath = "C:\bcbench"
if (Test-Path $repoPath) {
    Write-Skip "BC-Bench already cloned at $repoPath"
} else {
    git clone https://github.com/microsoft/BC-Bench.git $repoPath
    Push-Location $repoPath
    git checkout $Branch
    Pop-Location
    Write-Ok "BC-Bench cloned and checked out to $Branch"
}

# ---- 13. Install Python dependencies ----
Write-Step "Installing Python dependencies (uv sync)" 13 $totalSteps
Push-Location $repoPath
uv sync --all-groups
Pop-Location
Write-Ok "Python dependencies installed"

# ---- 14. Verify everything ----
Write-Step "Final verification" 14 $totalSteps

$checks = @(
    @{ Name = "Docker";            Cmd = { docker info 2>$null | Out-Null; $LASTEXITCODE -eq 0 } },
    @{ Name = "PowerShell 7";      Cmd = { $null -ne (Get-Command pwsh -EA SilentlyContinue) } },
    @{ Name = "Git";               Cmd = { $null -ne (Get-Command git -EA SilentlyContinue) } },
    @{ Name = "uv";                Cmd = { $null -ne (Get-Command uv -EA SilentlyContinue) } },
    @{ Name = "Node.js";           Cmd = { $null -ne (Get-Command node -EA SilentlyContinue) } },
    @{ Name = "Claude Code";       Cmd = { $null -ne (Get-Command claude -EA SilentlyContinue) } },
    @{ Name = "Copilot CLI";       Cmd = { ($null -ne (Get-Command copilot.cmd -EA SilentlyContinue)) -or ($null -ne (Get-Command copilot -EA SilentlyContinue)) } },
    @{ Name = "BcContainerHelper"; Cmd = { $null -ne (Get-Module -ListAvailable -Name BcContainerHelper) } },
    @{ Name = "ANTHROPIC_API_KEY"; Cmd = { -not [string]::IsNullOrEmpty($env:ANTHROPIC_API_KEY) } },
    @{ Name = "GITHUB_TOKEN";      Cmd = { -not [string]::IsNullOrEmpty($env:GITHUB_TOKEN) } },
    @{ Name = "BC-Bench repo";     Cmd = { Test-Path "C:\bcbench\pyproject.toml" } }
)

$failed = 0
foreach ($check in $checks) {
    if (& $check.Cmd) {
        Write-Host "  [OK] $($check.Name)" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $($check.Name)" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
if ($failed -eq 0) {
    Write-Host "============================================" -ForegroundColor Green
    Write-Host " ALL CHECKS PASSED — VM is ready!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host " Next steps:" -ForegroundColor Cyan
    Write-Host "   cd C:\bcbench" -ForegroundColor White
    Write-Host "   .\scripts\Setup-ALDCEvaluation.ps1 -TestRun -Category 'bug-fix'" -ForegroundColor White
    Write-Host ""
    Write-Host " For Copilot CLI runs (-Agent copilot), authenticate first:" -ForegroundColor Cyan
    Write-Host "   copilot auth login" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "============================================" -ForegroundColor Red
    Write-Host " $failed check(s) failed — review above" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
}

<#
.SYNOPSIS
    Phase 1: Install Windows features and reboot. Run BEFORE Setup-VM-Phase2.ps1.
.DESCRIPTION
    Installs Hyper-V and Containers features on Windows Server 2022.
    The machine will reboot automatically. After reboot, run Setup-VM-Phase2.ps1.
#>

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " BC-Bench VM Setup — Phase 1 (pre-reboot)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# 1. Install Hyper-V + Containers
Write-Host "[1/3] Installing Hyper-V..." -ForegroundColor Yellow
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -ErrorAction Stop
Write-Host "  OK: Hyper-V installed" -ForegroundColor Green

Write-Host "[2/3] Installing Containers feature..." -ForegroundColor Yellow
Install-WindowsFeature -Name Containers -ErrorAction Stop
Write-Host "  OK: Containers installed" -ForegroundColor Green

# 2. Disable Windows Defender real-time monitoring (improves BC compilation speed)
Write-Host "[3/3] Configuring Windows Defender exclusions..." -ForegroundColor Yellow
Set-MpPreference -DisableRealtimeMonitoring $true
Add-MpPreference -ExclusionPath "C:\bcbench", "C:\ProgramData\BcContainerHelper", "C:\testbed"
Write-Host "  OK: Defender real-time monitoring disabled + exclusions added" -ForegroundColor Green

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " Phase 1 complete. Rebooting in 10 seconds." -ForegroundColor Green
Write-Host " After reboot, run Setup-VM-Phase2.ps1" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

Start-Sleep -Seconds 10
Restart-Computer -Force

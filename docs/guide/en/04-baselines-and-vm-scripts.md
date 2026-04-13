---
layout: default
title: "Part 4 — Baselines & VM"
lang: en
---

# BC-Bench: Step-by-Step Guide

## Part 4 — Baseline Comparison and VM Scripts

---

## Preparing a VM for Evaluation

Full evaluations (with build + tests) require a **Windows Server with Docker/Hyper-V** to run Business Central containers. BC-Bench includes scripts to fully automate the VM setup.

### Two-Phase Setup Script

#### Phase 1: Install Windows features

```powershell
# Run as administrator on the VM
.\scripts\Setup-VM-Phase1.ps1
```

What it does:
1. Installs Hyper-V and the Containers feature
2. Disables Windows Defender real-time monitoring (improves BC compilation speed)
3. Adds Defender exclusions for `C:\bcbench`, `C:\ProgramData\BcContainerHelper`
4. **Reboots the machine automatically**

#### Phase 2: Install software (after reboot)

```powershell
.\scripts\Setup-VM-Phase2.ps1 `
  -AnthropicApiKey "sk-ant-..." `
  -GitHubToken "ghp_..." `
  -ContainerPassword "BcBench2026!"
```

What it installs (14 steps with verification):
1. Verifies Hyper-V
2. Docker
3. PowerShell 7 (v7.5.1)
4. Git (v2.47.1)
5. uv + Python 3.13
6. Node.js (v22.15.0)
7. Claude Code (`npm install -g @anthropic-ai/claude-code`)
8. GitHub Copilot CLI
9. BcContainerHelper (PowerShell module)
10. AL Tool (dotnet tool, v17.0.33.55542)
11. Environment variables (ANTHROPIC_API_KEY, GITHUB_TOKEN, BC_CONTAINER_*)
12. Clones BC-Bench to `C:\bcbench`
13. `uv sync --all-groups` (Python dependencies)
14. Full verification of all components

---

## BC Container and Repository Setup

Once the VM is prepared, you need to create the BC container and clone the evaluation repository.

### Container setup script

```powershell
.\scripts\Setup-ContainerAndRepository.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -ContainerName "bcbench" `
  -Username "admin"
```

What it does:
1. Reads the dataset entry to get the BC version and commit
2. Clones the repository to the specified path (or `$env:GITHUB_WORKSPACE\testbed`)
3. Checks out the correct `base_commit`
4. Downloads the BC artifact for the required version
5. Creates the Docker container with `New-BCContainerSync`
6. Creates the compiler folder
7. Initializes the container for development

> **Note**: The container is reused between evaluations that share the same `environment_setup_version`. It is only recreated when the BC version changes.

---

## Running Comparative Evaluations

### Main Script: Setup-ALDCEvaluation.ps1

This is the main script for launching evaluations. It supports multiple operation modes.

#### Simple evaluation (one scenario)

```powershell
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Agent claude `
  -Model claude-sonnet-4-6 `
  -Category bug-fix
```

#### Evaluation with a specific scenario

```powershell
# Baseline only (no custom configuration)
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Scenario baseline

# Developer agent only
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Scenario aldc-developer

# Conductor agent (TDD) only
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Scenario aldc-conductor

# Bugfix firstline agent only
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Scenario aldc-bugfix
```

#### Compare baseline vs custom configuration

```powershell
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -CompareBaseline
```

Runs two rounds: first baseline (no custom config), then with the active configuration in `config.yaml`.

#### Full comparison (3 scenarios)

```powershell
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -CompareAll `
  -PauseBetweenScenarios 180
```

Runs three rounds: baseline, developer, conductor. The `-PauseBetweenScenarios` parameter (in seconds) adds a wait between runs to avoid API overload errors.

#### Parameter reference

| Parameter | Values | Default |
|-----------|--------|---------|
| `-InstanceId` | Dataset ID | (all if omitted) |
| `-Agent` | `claude`, `copilot` | `claude` |
| `-Model` | See model list | `claude-sonnet-4-6` |
| `-Category` | `bug-fix`, `test-generation` | `bug-fix` |
| `-Scenario` | `baseline`, `aldc-developer`, `aldc-conductor`, `aldc-bugfix` | (none) |
| `-CompareBaseline` | Switch | `$false` |
| `-CompareAll` | Switch | `$false` |
| `-AlMcp` | Switch | `$true` |
| `-SkipContainerSetup` | Switch | `$false` |
| `-SkipRepoClone` | Switch | `$false` |
| `-TestRun` | Switch (only 2 entries) | `$false` |
| `-PauseBetweenScenarios` | Seconds | `0` |

---

## Full Multi-Agent Comparison: Run-FullComparison.ps1

This script runs **all scenarios** for **both agents** (Claude + Copilot), collects results, generates a report, and pushes it to the repository.

### What scenarios it runs

The script defines 8 scenarios (4 per agent):

| # | Agent | Scenario | Output Directory |
|---|-------|----------|-----------------|
| 1 | Claude Code | baseline | `eval_claude_baseline_{model}` |
| 2 | Claude Code | developer | `eval_claude_aldc_developer_{model}` |
| 3 | Claude Code | conductor | `eval_claude_aldc_conductor_{model}` |
| 4 | Claude Code | bugfix | `eval_claude_aldc_bugfix_{model}` |
| 5 | Copilot | baseline | `eval_copilot_baseline_{model}` |
| 6 | Copilot | developer | `eval_copilot_aldc_developer_{model}` |
| 7 | Copilot | conductor | `eval_copilot_aldc_conductor_{model}` |
| 8 | Copilot | bugfix | `eval_copilot_aldc_bugfix_{model}` |

### Basic usage

```powershell
.\scripts\Run-FullComparison.ps1 `
  -InstanceIds "microsoft__BCApps-4822"
```

### With multiple instances

```powershell
.\scripts\Run-FullComparison.ps1 `
  -InstanceIds @("microsoft__BCApps-4822", "microsoft__BCApps-4699", "microsoft__BCApps-4766")
```

### With Opus model

```powershell
.\scripts\Run-FullComparison.ps1 `
  -LlmFamily opus `
  -InstanceIds "microsoft__BCApps-4822"
```

The `-LlmFamily` parameter automatically derives model IDs:
- Claude Code: `claude-{family}-4-6` (e.g., `claude-opus-4-6`)
- Copilot: `claude-{family}-4.6` (e.g., `claude-opus-4.6`)

### Full production example

```powershell
# Update scripts first
git -C C:\bcbench pull origin main

# Run full comparison with auto-shutdown
.\scripts\Run-FullComparison.ps1 `
  -InstanceIds @("microsoft__BCApps-4822") `
  -LlmFamily sonnet `
  -OnlyMissing `
  -EmailTo "your-email@gmail.com" `
  -AutoShutdown
```

Key parameters:
- `-OnlyMissing`: Skip scenarios that already have results (to resume failed runs)
- `-EmailTo`: Send summary email on completion (requires `$env:GMAIL_APP_PASSWORD`)
- `-AutoShutdown`: Shut down the VM after completion (saves cloud costs)
- `-SkipClaude` / `-SkipCopilot`: Run only one agent
- `-PauseBetweenScenarios`: Seconds to wait between scenarios (default: 30)

### What it does on completion

1. **Collects results** from all output directories
2. **Generates a markdown report** with a comparison table
3. **Pushes via git** the results to the configured branch
4. **Sends email** with summary (if configured)
5. **Shuts down the VM** (if `-AutoShutdown`)

---

## Ready-to-Use Examples

### Example 1: Evaluate a bug with Claude Code baseline vs custom config

```powershell
# Step 1: Ensure the container exists
.\scripts\Setup-ContainerAndRepository.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -RepoPath "C:\bcbench\testbed"

# Step 2: Run baseline
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Scenario baseline `
  -Agent claude `
  -Model claude-sonnet-4-6 `
  -RepoPath "C:\bcbench\testbed" `
  -OutputDir "C:\bcbench\eval_baseline"

# Step 3: Run with custom configuration (reuse container)
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Scenario aldc-developer `
  -Agent claude `
  -Model claude-sonnet-4-6 `
  -SkipContainerSetup `
  -SkipRepoClone `
  -RepoPath "C:\bcbench\testbed" `
  -OutputDir "C:\bcbench\eval_developer"
```

### Example 2: Evaluate test-generation with the conductor agent

```powershell
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Category test-generation `
  -Scenario aldc-conductor `
  -Agent claude `
  -Model claude-opus-4-6
```

### Example 3: Evaluate multiple instances with Copilot

```powershell
.\scripts\Run-FullComparison.ps1 `
  -InstanceIds @(
    "microsoft__BCApps-4822",
    "microsoft__BCApps-4699",
    "microsoft__BCApps-4766"
  ) `
  -SkipClaude `
  -LlmFamily sonnet `
  -Category bug-fix `
  -OnlyMissing
```

### Example 4: Run scenarios manually with pauses

Useful when the API returns overload errors (`overloaded_error`):

```powershell
# Scenario 1: Baseline
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Scenario baseline `
  -RepoPath "C:\bcbench\testbed"

# Wait 5 minutes
Start-Sleep -Seconds 300

# Scenario 2: Developer
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Scenario aldc-developer `
  -SkipContainerSetup -SkipRepoClone `
  -RepoPath "C:\bcbench\testbed"

# Wait 5 minutes
Start-Sleep -Seconds 300

# Scenario 3: Conductor
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-4822" `
  -Scenario aldc-conductor `
  -SkipContainerSetup -SkipRepoClone `
  -RepoPath "C:\bcbench\testbed"
```

---

> **Next**: [Part 5 — Obtaining, Analyzing and Documenting Results](05-results-and-analysis.md)

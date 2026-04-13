---
layout: default
title: "Part 2 — Setup"
lang: en
---

# BC-Bench: Step-by-Step Guide

## Part 2 — Installation, Setup and First Evaluation

---

## Prerequisites

### Required Software

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| [uv](https://docs.astral.sh/uv/) | Latest | Python package manager (replaces pip/venv) |
| Python | 3.13+ | Harness runtime |
| Git | 2.40+ | Repository management |
| Node.js | 22+ | Required for Claude Code |
| Docker + Hyper-V | — | Business Central containers (Windows only) |
| PowerShell | 7+ | Evaluation scripts (Windows only) |

### Agent Tools (depending on which you use)

| Agent | Installation | Environment Variable |
|-------|-------------|---------------------|
| Claude Code | `npm install -g @anthropic-ai/claude-code` | `ANTHROPIC_API_KEY` |
| GitHub Copilot CLI | Via GitHub CLI | `GITHUB_TOKEN` |
| mini-bc-agent | Included in BC-Bench | `AZURE_API_KEY`, `AZURE_API_BASE` |

### PowerShell Modules (for evaluation with BC container)

| Module | Purpose |
|--------|---------|
| BcContainerHelper | Create and manage Business Central containers |
| AL Tool (dotnet tool) | AL MCP server (compilation, analysis) |

---

## Step-by-Step Installation

### Step 1: Clone the repository

```bash
# Fork and clone (recommended for your own use)
gh repo fork microsoft/BC-Bench --clone
cd BC-Bench

# Or direct clone
git clone https://github.com/microsoft/BC-Bench.git
cd BC-Bench
```

### Step 2: Install Python and dependencies

```bash
# Install Python 3.13 via uv
uv python install

# Install all dependencies (including dev and analysis)
uv sync --all-groups

# Install pre-commit hooks
uv run pre-commit install
```

### Step 3: Verify the installation

```bash
# Show CLI help
uv run bcbench --help
```

You should see:

```
Usage: bcbench [OPTIONS] COMMAND [ARGS]...

BC-Bench: Benchmarking tool for Business Central (AL) ecosystem

Commands:
  collect    Collect dataset entries
  dataset    Query and analyze dataset
  evaluate   Evaluate agents on benchmark datasets
  result     Process and display evaluation results
  run        Run agents on single dataset entry
```

### Step 4: Configure environment variables

Copy the sample file and fill in your credentials:

```bash
cp .env.sample .env
```

Key variables in `.env`:

```ini
# For Claude Code
ANTHROPIC_API_KEY=sk-ant-...

# For GitHub Copilot CLI
GITHUB_TOKEN=ghp_...

# For mini-bc-agent (Azure AI Foundry)
AZURE_API_KEY=...
AZURE_API_BASE=...
AZURE_API_VERSION=...

# For BC containers (full evaluation)
BC_CONTAINER_NAME=bcbench
BC_CONTAINER_USERNAME=admin
BC_CONTAINER_PASSWORD=YourPassword123!
```

---

## Exploring the Dataset

Before running an evaluation, familiarize yourself with the dataset.

### List all entries

```bash
uv run bcbench dataset list
```

This shows all 101 available entries:

```
Found 101 entry(ies):
  - microsoftInternal__NAV-210528
  - microsoftInternal__NAV-224009
  - microsoft__BCApps-4822
  ...
```

### View entry details

```bash
uv run bcbench dataset view microsoft__BCApps-4822
```

Shows detailed information: repo, commit, BC version, project paths, tests, and the problem statement.

To also see the gold patch:

```bash
uv run bcbench dataset view microsoft__BCApps-4822 --show-patch
```

### Browse the dataset with the interactive TUI

```bash
uv run bcbench dataset review
```

Opens a terminal interface with a split view: entry information on the left, problem statement on the right. Use arrow keys to navigate between entries.

To also show resolution statistics (if you have previous results):

```bash
uv run bcbench dataset review --results-dir notebooks/result/bug-fix/my-directory/
```

---

## Your First Evaluation

There are two execution modes:

| Mode | Command | What it does | Requires BC container? |
|------|---------|-------------|----------------------|
| **run** | `bcbench run` | Only runs the agent and generates the patch | No |
| **evaluate** | `bcbench evaluate` | Runs the agent + compiles + runs tests | Yes |

### Quick mode: generate patch only (no container)

This mode is ideal for getting started. You don't need a BC container — just the agent and the BCApps repository cloned locally.

#### With Claude Code

```bash
uv run bcbench run claude microsoft__BCApps-4822 \
  --category bug-fix \
  --model claude-sonnet-4-6 \
  --container-name bcbench \
  --repo-path /path/to/BCApps
```

#### With GitHub Copilot CLI

```bash
uv run bcbench run copilot microsoft__BCApps-4822 \
  --category bug-fix \
  --model claude-sonnet-4.6 \
  --container-name bcbench \
  --repo-path /path/to/BCApps
```

#### With mini-bc-agent

```bash
uv run bcbench run mini microsoft__BCApps-4822 \
  --category bug-fix \
  --model gpt-5.1-codex-mini \
  --repo-path /path/to/BCApps
```

> **Note on model IDs**: Claude Code uses hyphens (`claude-sonnet-4-6`), Copilot uses dots (`claude-sonnet-4.6`). They are different ID formats for the same model.

### Full mode: evaluation with build + tests

This mode requires a running Business Central container (Windows with Docker/Hyper-V).

```bash
uv run bcbench evaluate claude microsoft__BCApps-4822 \
  --category bug-fix \
  --model claude-sonnet-4-6 \
  --container-name bcbench \
  --username admin \
  --password "YourPassword123!" \
  --repo-path C:\depot\BCApps \
  --run-id my_first_evaluation
```

Key parameters:

| Parameter | Description |
|-----------|------------|
| `--category` | `bug-fix` or `test-generation` |
| `--model` | LLM model to use |
| `--container-name` | BC container name |
| `--run-id` | Unique identifier for this run |
| `--al-mcp` | Enable the AL MCP server (compiler access) |
| `--output-dir` | Directory for saving results |

### Enabling the AL MCP server

The `--al-mcp` flag gives the agent access to the AL compiler via MCP (Model Context Protocol). This lets it compile and get compilation errors during execution:

```bash
uv run bcbench evaluate claude microsoft__BCApps-4822 \
  --category bug-fix \
  --model claude-sonnet-4-6 \
  --container-name bcbench \
  --username admin \
  --password "YourPassword123!" \
  --al-mcp
```

> **Requirement**: The AL Tool must be installed: `dotnet tool install -g Microsoft.Dynamics.BusinessCentral.Development.Tools`

---

## Available Models

### For Claude Code

| Model | ID |
|-------|-----|
| Claude Sonnet 4.6 | `claude-sonnet-4-6` |
| Claude Opus 4.6 | `claude-opus-4-6` |
| Claude Haiku 4.5 | `claude-haiku-4-5` |

### For GitHub Copilot CLI

| Model | ID |
|-------|-----|
| Claude Sonnet 4.6 | `claude-sonnet-4.6` |
| Claude Opus 4.6 | `claude-opus-4.6` |
| Claude Haiku 4.5 | `claude-haiku-4.5` |
| GPT 5.4 | `gpt-5.4` |
| GPT 5.2 | `gpt-5.2` |
| GPT 4.1 | `gpt-4.1` |

### For mini-bc-agent

| Model | ID |
|-------|-----|
| GPT 5.1 Codex Mini | `gpt-5.1-codex-mini` |

---

## What to Expect from the Result

After evaluation, the result is saved as a JSONL file (`{instance_id}.jsonl`) with this structure:

```json
{
  "instance_id": "microsoft__BCApps-4822",
  "model": "claude-sonnet-4-6",
  "agent_name": "Claude Code",
  "category": "bug-fix",
  "resolved": true,
  "build": true,
  "timeout": false,
  "generated_patch": "--- a/...\n+++ b/...",
  "error_message": null,
  "metrics": {
    "execution_time": 145.3,
    "llm_duration": 120.5,
    "turn_count": 12,
    "prompt_tokens": 450000,
    "completion_tokens": 3500,
    "tool_usage": {
      "Read": 15,
      "Grep": 8,
      "Edit": 3,
      "Glob": 5
    }
  },
  "experiment": {
    "mcp_servers": ["altool", "mslearn"],
    "custom_instructions": true,
    "skills_enabled": true,
    "custom_agent": "al-developer-bench"
  }
}
```

Result fields:
- **resolved**: `true` if the agent solved the bug (tests pass)
- **build**: `true` if the code compiled successfully
- **timeout**: `true` if the agent exceeded the 60-minute timeout
- **metrics**: Detailed execution metrics
- **experiment**: Exact configuration used (for reproducibility)

---

> **Next**: [Part 3 — Agent Configuration and Customization](03-agent-configuration.md)

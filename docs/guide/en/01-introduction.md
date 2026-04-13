---
layout: default
title: "Part 1 — Introduction"
lang: en
---

# BC-Bench: Step-by-Step Guide

## Part 1 — Introduction and Core Concepts

---

## What is BC-Bench?

BC-Bench is an **open-source benchmarking framework** created by Microsoft to evaluate coding agents on real-world **Microsoft Dynamics 365 Business Central** development tasks using the **AL** language.

It is inspired by [SWE-Bench](https://github.com/swe-bench/SWE-bench), the reference benchmark for evaluating AI agents on software engineering tasks, but adapted to the Business Central ecosystem with its specific requirements: AL app compilation, BC containers, codeunit tests, and the BCApps project structure.

### What is it for?

BC-Bench allows you to answer concrete questions such as:

- **"Which model resolves the most real BC bugs?"** — Compare Claude Sonnet vs Opus vs GPT on identical tasks
- **"Do custom instructions improve outcomes?"** — Measure the impact of custom instructions, skills, and specialized agents
- **"Does the AL MCP server add value?"** — Quantify whether giving the agent access to the AL compiler improves performance
- **"Which agent configuration is best for my team?"** — Rapidly iterate over different setups and compare results

### How does it work at a high level?

```
1. DATASET: 101 real Business Central bugs with gold patches and tests
       |
2. AGENT: A coding agent (Claude Code, Copilot CLI, mini-bc-agent) attempts to fix the bug
       |
3. EVALUATION: The test patch is applied, code is compiled, and tests run inside a BC container
       |
4. RESULT: resolved/failed + metrics (tokens, time, tools used)
```

Each task in the dataset comes from a real bug reported in the BCApps or NAV repository. The dataset includes:
- The **problem statement** (bug description, reproduction steps, screenshots)
- The **base_commit** (the state of the code before the fix)
- The **patch** (the gold-standard solution)
- The **test_patch** (tests that validate whether the fix is correct)
- The **FAIL_TO_PASS tests** (which must fail without the fix and pass with it)

---

## Repository Architecture

```
BC-Bench/
|-- src/bcbench/           # Evaluation harness (Python)
|   |-- agent/             # Agent implementations (mini, claude, copilot)
|   |   |-- shared/        # Shared configuration: prompts, skills, instructions
|   |   |   |-- config.yaml           # Main agent configuration
|   |   |   |-- instructions/         # Custom instructions per repository
|   |   |       |-- microsoft-BCApps/ # Instructions, skills, agents for BCApps
|   |   |       |-- microsoftInternal-NAV/  # Instructions for NAV
|   |   |-- mini/          # mini-bc-agent (minimal baseline)
|   |   |-- claude/        # Claude Code integration
|   |   |-- copilot/       # GitHub Copilot CLI integration
|   |-- commands/          # CLI commands (run, evaluate, dataset, result)
|   |-- evaluate/          # Evaluation pipelines (bug-fix, test-generation)
|   |-- results/           # Result classes, metrics, leaderboard
|   |-- operations/        # BC operations (build, test, git, setup)
|-- dataset/
|   |-- bcbench.jsonl      # Main dataset (101 entries)
|   |-- problemstatement/  # Problem statements with README.md and images
|-- scripts/               # PowerShell scripts for VM and evaluation
|-- notebooks/             # Jupyter notebooks for result analysis
|-- docs/                  # Documentation and leaderboard
|-- tests/                 # Harness unit tests
```

---

## Key Concepts

### Evaluation Categories

BC-Bench supports two categories:

| Category | What the agent does | How it is evaluated |
|----------|--------------------|--------------------|
| **bug-fix** | Receives the bug description and must produce the patch that fixes it | The test_patch is applied, compiled, and tests are run. If they pass: resolved |
| **test-generation** | Receives the bug (and optionally the fix) and must generate tests that reproduce it | Tests must FAIL against unfixed code and PASS with the fix applied |

### Available Agents

| Agent | Description | Primary Use |
|-------|------------|-------------|
| **mini-bc-agent** | Minimal loop based on mini-swe-agent. PowerShell only. | Reference baseline |
| **Claude Code** | Anthropic's agentic tool. Supports MCP, custom instructions, agents. | Advanced evaluation |
| **GitHub Copilot CLI** | GitHub Copilot CLI. Supports MCP, tools, agent mode. | Advanced evaluation |

### Comparison Scenarios

A **scenario** is a combination of agent + configuration. Typical scenarios are:

| Scenario | What it includes |
|----------|-----------------|
| **baseline** | Agent with no custom instructions, no skills, no custom agents |
| **with instructions** | Agent + custom instructions (CLAUDE.md or copilot-instructions.md) |
| **with instructions + skills** | Agent + instructions + specialized skills (bugfix, debug, testing...) |
| **with specialized agent** | All of the above + a custom agent (al-developer-bench, al-conductor-bench...) |

### Dataset Entry Structure

Each line in `dataset/bcbench.jsonl` is a JSON object with this structure:

```json
{
  "instance_id": "microsoft__BCApps-4822",
  "repo": "microsoft/BCApps",
  "base_commit": "a1b2c3d4...",
  "created_at": "2025-01-15",
  "environment_setup_version": "26.0",
  "project_paths": [
    "App\\Apps\\W1\\Shopify\\app",
    "App\\Apps\\W1\\Shopify\\test"
  ],
  "FAIL_TO_PASS": [
    {
      "codeunitID": 139648,
      "functionName": ["UnitTestSuggestShopifyPaymentsFailedTransaction"]
    }
  ],
  "PASS_TO_PASS": [],
  "patch": "--- a/...\n+++ b/...\n@@ ...",
  "test_patch": "--- a/...\n+++ b/...\n@@ ...",
  "metadata": {
    "area": "shopify",
    "image_count": 3
  }
}
```

Key fields:
- **instance_id**: Unique identifier. Format: `{repo}__{issue-number}`
- **base_commit**: SHA of the commit where the bug exists (before the fix)
- **environment_setup_version**: Required BC version (e.g., "26.0" = BC 2025 Wave 1)
- **project_paths**: Affected AL directories (always includes app + test)
- **FAIL_TO_PASS**: Tests that must fail without fix and pass with it
- **patch**: The gold-standard patch (the correct solution)
- **test_patch**: Patch that adds validation tests

### Problem Statements

Each entry has a directory at `dataset/problemstatement/{instance_id}/` with:
- `README.md` — Bug description, reproduction steps, expected vs actual result
- PNG images — Screenshots of the bug (referenced from the README)

Typical problem statement example:

```markdown
# Title: Shopify - Export customer as location - Sell-to and Bill-to are missing
## Repro Steps:
1. Export two companies to Shopify
2. One normal, another with a different bill-to defined
...
**ACTUAL RESULT:** Sell-to and Bill-to fields are empty
**EXPECTED RESULT:** Fields should be populated correctly
```

---

## Full Evaluation Flow

This is the flow for each individual evaluation (bug-fix category):

```
1. SETUP
   |-- Clean repository (git clean, checkout base_commit)
   |-- Copy problem statement into the repo
   |-- Compile base projects (timeout: 30 min BaseApp, 5 min apps)
   |-- Copy instructions/skills/agents (if enabled)

2. AGENT EXECUTION
   |-- Build prompt with task and context
   |-- Configure MCP servers (if --al-mcp is enabled)
   |-- Execute agent (timeout: 60 min)
   |-- Capture metrics: tokens, time, tools, turns

3. EVALUATION
   |-- Capture agent-generated patch (git diff)
   |-- Apply test_patch (adds validation tests)
   |-- Compile with tests (timeout: 5 min)
   |-- Run tests (timeout: 3 min per test)
   |-- Determine result: resolved / build-failure / test-failure

4. RESULT
   |-- Save to {instance_id}.jsonl
   |-- Includes: resolved, build, patch, metrics, configuration
```

### Default Timeouts

| Operation | Timeout |
|-----------|---------|
| BaseApp compilation | 30 minutes |
| App compilation | 5 minutes |
| Test execution | 3 minutes |
| Agent execution | 60 minutes |

---

> **Next**: [Part 2 — Installation, Setup and First Evaluation](02-setup-and-first-evaluation.md)

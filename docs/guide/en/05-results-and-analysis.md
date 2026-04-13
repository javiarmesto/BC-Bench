---
layout: default
title: "Part 5 — Results"
lang: en
---

# BC-Bench: Step-by-Step Guide

## Part 5 — Obtaining, Analyzing and Documenting Results

---

## Result Structure

After an evaluation, results are saved in the output directory with this structure:

```
evaluation_results/
|-- {run_id}/
    |-- {instance_id}.jsonl          # Per-instance result
    |-- evaluation_summary.json      # Aggregated summary
    |-- bceval_results.jsonl         # Export in bceval format
    |-- claude_debug.log             # Debug log (Claude Code)
    |-- copilot-*.log                # Debug log (Copilot)
```

Each `.jsonl` file contains one JSON line per result with:

```json
{
  "instance_id": "microsoft__BCApps-4822",
  "project": "BCApps",
  "model": "claude-sonnet-4-6",
  "agent_name": "Claude Code",
  "category": "bug-fix",
  "resolved": true,
  "build": true,
  "timeout": false,
  "generated_patch": "--- a/...\n+++ b/...",
  "error_message": null,
  "benchmark_version": "0.4.0",
  "metrics": {
    "execution_time": 145.3,
    "llm_duration": 120.5,
    "turn_count": 12,
    "prompt_tokens": 450000,
    "completion_tokens": 3500,
    "tool_usage": { "Read": 15, "Grep": 8, "Edit": 3 }
  },
  "experiment": {
    "mcp_servers": ["altool"],
    "custom_instructions": true,
    "skills_enabled": true,
    "custom_agent": "al-developer-bench"
  }
}
```

---

## Result CLI Commands

### Summarize a run

```bash
uv run bcbench result summarize {run_id}
```

Reads all `.jsonl` files from `evaluation_results/{run_id}/`, calculates aggregated metrics and displays a console summary:

- Total instances evaluated
- Resolved vs failed
- Successful build rate
- Average tokens, time, turns
- Pass rate

Also generates:
- `evaluation_summary.json` — Summary in JSON format
- `bceval_results.jsonl` — Export for external analysis

### Aggregate results from a directory

```bash
uv run bcbench result aggregate --input-dir notebooks/result/bug-fix/my-directory/
```

Similar to `summarize`, but does not require a specific `run_id`. Recursively scans the directory for all result `.jsonl` files.

### Review results with the interactive TUI

```bash
# Review all unresolved results from a file
uv run bcbench result review results.jsonl --category bug-fix

# Review a specific instance across all runs in a directory
uv run bcbench result review notebooks/result/bug-fix/ \
  --category bug-fix \
  --instance-id microsoft__BCApps-4822

# Include resolved instances too
uv run bcbench result review results.jsonl \
  --category bug-fix \
  --include-resolved
```

The TUI shows a split view: expected patch (gold) vs generated patch (agent). Use `j/k` or arrow keys to navigate, `1-7` to classify failure categories.

### Update the leaderboard

```bash
uv run bcbench result update evaluation_results/{run_id}/evaluation_summary.json
```

Takes a run summary and adds it to the public leaderboard at `docs/_data/{category}.json`. Stores up to 5 runs per agent + model + configuration combination.

### Refresh leaderboard aggregates

```bash
uv run bcbench result refresh
```

Recalculates leaderboard aggregated metrics without adding new data. Useful when aggregation logic changes.

---

## Statistical Metrics

BC-Bench calculates advanced statistical metrics:

### Pass Rate

```
pass_rate = resolved / total * 100
```

The basic metric: percentage of resolved instances.

### Bootstrap Confidence Intervals

BC-Bench uses BCa (bias-corrected and accelerated) bootstrapping to calculate 95% confidence intervals. This answers: "How confident can we be that the pass rate is X%?"

### Pass@k

Probability of getting at least 1 correct solution in k attempts:

```
pass@k = 1 - C(n-c, k) / C(n, k)
```

Where `n` = total, `c` = correct. Useful when running multiple runs of the same scenario.

### Pass^k

Probability that ALL k attempts are correct:

```
pass^k = estimated probability of consistent success
```

---

## Analysis with Notebooks

BC-Bench includes Jupyter notebooks for visual result analysis:

```
notebooks/
|-- dataset.ipynb                        # Dataset statistics
|-- bug-fix/
|   |-- overview.ipynb                   # Bug-fix overview
|   |-- claude-vs-copilot.ipynb          # Claude vs Copilot comparison
|   |-- failure-analysis.ipynb           # Failure analysis
|   |-- altool-comparison.ipynb          # AL MCP impact
|   |-- claude-code-aldc-comparison.ipynb  # With/without custom config comparison
|   |-- aldc-comparison-full.ipynb       # Full scenario comparison
|-- test-generation/
    |-- overview.ipynb                   # Test-generation overview
    |-- altest-comparison.ipynb          # Configuration comparison
```

### Running notebooks

```bash
# Install analysis dependencies
uv sync --group analysis

# Launch Jupyter
uv run jupyter lab
```

Analysis dependencies include: `pandas`, `plotly`, `ipykernel`, `nbformat`.

### Leaderboard data

Notebooks read aggregated data from:

```
docs/_data/bug-fix.json
docs/_data/test-generation.json
```

Leaderboard structure:

```json
{
  "runs": [
    {
      "total": 101,
      "resolved": 57,
      "failed": 44,
      "build": 100,
      "percentage": 56.4,
      "date": "2026-01-29",
      "model": "claude-opus-4-5",
      "agent_name": "Claude Code",
      "category": "bug-fix",
      "average_duration": 197.3,
      "average_prompt_tokens": 685413.2,
      "average_completion_tokens": 4821.8,
      "instance_results": {
        "microsoftInternal__NAV-204450": false,
        "microsoftInternal__NAV-179733": true
      }
    }
  ],
  "aggregate": [...]
}
```

---

## Complete Workflow: From Evaluation to Report

### Step 1: Run the evaluation

```powershell
# On the VM
.\scripts\Run-FullComparison.ps1 `
  -InstanceIds @("microsoft__BCApps-4822") `
  -LlmFamily sonnet `
  -OnlyMissing
```

### Step 2: Collect and summarize results

```bash
# On your development machine
uv run bcbench result aggregate --input-dir notebooks/result/bug-fix/claude-baseline-sonnet-4-6/
uv run bcbench result aggregate --input-dir notebooks/result/bug-fix/claude-aldc-developer-sonnet-4-6/
```

### Step 3: Update leaderboard

```bash
uv run bcbench result update evaluation_results/my_run/evaluation_summary.json
```

### Step 4: Review failures

```bash
# Review instances that failed
uv run bcbench result review notebooks/result/bug-fix/claude-baseline-sonnet-4-6/ \
  --category bug-fix \
  --instance-id microsoft__BCApps-4822
```

### Step 5: Visual analysis with notebooks

```bash
uv run jupyter lab notebooks/bug-fix/overview.ipynb
```

---

## Result Versioning

BC-Bench uses [semantic versioning](https://semver.org/). The current version is defined in `pyproject.toml`:

```toml
[project]
version = "0.4.0"
```

### Versioning rules

| Change type | Bump | Examples |
|------------|------|----------|
| **Major** (X.0.0) | Dataset or methodology changes | Adding/removing entries, changing pass criteria |
| **Minor** (0.X.0) | Tooling changes that affect results | Updating Copilot version, changing agent prompts |
| **Patch** (0.0.X) | Fixes and documentation | Fixing a parsing bug, updating docs |

### Cross-version compatibility

**Results from different versions CANNOT be aggregated together.** The `bcbench result update` command validates that all runs have the same `benchmark_version`. This ensures the leaderboard always compares apples to apples.

---

## Checklist for Documenting an Evaluation

When documenting evaluation results, make sure to include:

- [ ] **Date** of the evaluation
- [ ] **BC-Bench version** used (`pyproject.toml`)
- [ ] **Instances evaluated** (dataset IDs)
- [ ] **LLM model** and version
- [ ] **Agent** (Claude Code, Copilot, mini-bc-agent)
- [ ] **Scenario** (baseline, developer, conductor, bugfix)
- [ ] **Category** (bug-fix, test-generation)
- [ ] **AL MCP** enabled or not
- [ ] **Results table** (resolved, build, tokens, time)
- [ ] **Observations** about relevant failures
- [ ] **Comparison** with baseline or other scenarios

---

## Common Troubleshooting

### Agent exceeds the 60-minute timeout

- Verify the model is appropriate (Haiku is faster than Opus)
- Check if the agent is stuck in a loop (use `bcbench run mini-inspector` for trajectories)

### Build failure (build: false)

- Verify the BC container version matches `environment_setup_version`
- Ensure the repository is at the correct `base_commit`

### API overloaded_error

- Use `-PauseBetweenScenarios 180` (3 minutes between scenarios)
- Or run scenarios manually with pauses

### Container not responding

- Check: `docker ps` to see if it's running
- Recreate: remove with `docker rm -f bcbench` and re-run setup

### Results from different versions cannot be aggregated

- Ensure all runs use the same BC-Bench version
- If you changed something that affects results, bump the version in `pyproject.toml`

---

> **Back to index**: [Guide Index](../README.md)

# BC-Bench Cheat Sheet

Quick reference for the most common operations.

---

## CLI Commands

```bash
# ── Dataset ──────────────────────────────────────────────────
bcbench dataset list                              # List all 101 entries
bcbench dataset list --test-run                   # List 2 random entries (quick test)
bcbench dataset view <ID> --show-patch            # View entry details + patches
bcbench dataset review                            # Interactive TUI browser

# ── Run (patch only, no container needed) ────────────────────
bcbench run claude <ID> --category bug-fix --model claude-sonnet-4-6 --container-name bcbench
bcbench run copilot <ID> --category bug-fix --model claude-sonnet-4.6 --container-name bcbench
bcbench run mini <ID> --category bug-fix --model gpt-5.1-codex-mini

# ── Evaluate (full: patch + build + tests) ───────────────────
bcbench evaluate claude <ID> --category bug-fix --model claude-sonnet-4-6 \
  --container-name bcbench --username admin --password "Pass!" --al-mcp

bcbench evaluate copilot <ID> --category bug-fix --model claude-sonnet-4.6 \
  --container-name bcbench --username admin --password "Pass!" --al-mcp

# ── Results ──────────────────────────────────────────────────
bcbench result summarize <run_id>                 # Summarize a single run
bcbench result aggregate --input-dir <dir>        # Aggregate from directory
bcbench result review <file.jsonl> -c bug-fix     # Interactive TUI reviewer
bcbench result update <summary.json>              # Update leaderboard
bcbench result refresh                            # Recalculate leaderboard aggregates

# ── Inspectors ───────────────────────────────────────────────
bcbench run mini-inspector <dir>                  # Inspect mini-agent trajectories
bcbench run copilot-inspector <log_file>          # Inspect Copilot session logs
```

All commands support `-v` for verbose/debug output. Prefix with `uv run` if not installed globally.

---

## Models Quick Reference

| Agent | Model ID | Family |
|-------|----------|--------|
| Claude Code | `claude-sonnet-4-6` | Sonnet |
| Claude Code | `claude-opus-4-6` | Opus |
| Claude Code | `claude-haiku-4-5` | Haiku |
| Copilot | `claude-sonnet-4.6` | Sonnet |
| Copilot | `claude-opus-4.6` | Opus |
| Copilot | `gpt-5.4` | GPT |
| mini-bc-agent | `gpt-5.1-codex-mini` | Codex |

---

## config.yaml Quick Toggles

```yaml
# Baseline (everything off)
instructions:
  enabled: false
skills:
  enabled: false
agents:
  enabled: false

# Full (everything on)
instructions:
  enabled: true
skills:
  enabled: true
  include: [skill-al-bugfix, skill-debug, skill-testing, skill-events, skill-performance, skill-api, skill-permissions]
agents:
  enabled: true
  name: al-developer-bench     # or: al-conductor-bench, al-bugfix-firstline
```

---

## PowerShell Scripts (VM)

```powershell
# VM setup (run once)
.\scripts\Setup-VM-Phase1.ps1                                           # Phase 1 + reboot
.\scripts\Setup-VM-Phase2.ps1 -AnthropicApiKey "sk-..." -GitHubToken "ghp-..."  # Phase 2

# Container + repo setup
.\scripts\Setup-ContainerAndRepository.ps1 -InstanceId "microsoft__BCApps-4822"

# Single evaluation
.\scripts\Setup-ALDCEvaluation.ps1 -InstanceId "microsoft__BCApps-4822" -Scenario baseline
.\scripts\Setup-ALDCEvaluation.ps1 -InstanceId "microsoft__BCApps-4822" -Scenario aldc-developer

# Full comparison (8 scenarios: 4 per agent)
.\scripts\Run-FullComparison.ps1 -InstanceIds "microsoft__BCApps-4822" -LlmFamily sonnet -OnlyMissing
```

---

## Evaluation Scenarios

| Scenario | Instructions | Skills | Agent | config.yaml changes |
|----------|:-----------:|:------:|:-----:|-------------------|
| `baseline` | off | off | off | All `enabled: false` |
| `aldc-developer` | on | on | al-developer-bench | All `enabled: true`, name: al-developer-bench |
| `aldc-conductor` | on | on | al-conductor-bench | All `enabled: true`, name: al-conductor-bench |
| `aldc-bugfix` | on | on | al-bugfix-firstline | All `enabled: true`, name: al-bugfix-firstline |

---

## Timeouts

| Operation | Default |
|-----------|---------|
| BaseApp compilation | 30 min |
| App compilation | 5 min |
| Test execution | 3 min |
| Agent execution | 60 min |

---

## Key Paths

| What | Path |
|------|------|
| Dataset | `dataset/bcbench.jsonl` |
| Problem statements | `dataset/problemstatement/{id}/README.md` |
| Agent config | `src/bcbench/agent/shared/config.yaml` |
| Instructions source | `src/bcbench/agent/shared/instructions/{repo}/` |
| Evaluation results | `evaluation_results/{run_id}/` |
| Leaderboard data | `docs/_data/bug-fix.json`, `test-generation.json` |
| Notebooks | `notebooks/bug-fix/`, `notebooks/test-generation/` |
| VM scripts | `scripts/*.ps1` |

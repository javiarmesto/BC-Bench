# Evaluation Log — ALDC on BC-Bench

## Infrastructure

| Resource | Value |
|----------|-------|
| VM | `vm-bcbench` (Standard_D8s_v3, 8 vCPUs, 32GB RAM) |
| OS | Windows Server 2022 Gen1 |
| Region | West Europe |
| IP | 52.142.212.229 |
| RG | rg-bcbench |
| Subscription | Visual Studio Enterprise - MPN |

### VM Software Stack
Docker 27.5.1, PowerShell 7.5.1, Git 2.47.1, uv 0.11.3, Python 3.13, Node.js 22.15.0, Claude Code 2.1.69, BcContainerHelper, AL Tool, .NET SDK 8.0

## Code Fixes (branch: claude/explain-repo-usage-2rL3g)

| Commit | Description |
|--------|-------------|
| `95d6e6c` | feat: add --category flag, result aggregate command, fix evaluate cleanup, VM setup scripts |
| `fb58c43` | fix: use str for --category, fix TestRun entry parsing in script |
| `42dd541` | fix: replace ?? with PS 5.1-compatible syntax |
| `cc2049f` | fix: replace multi-arg Join-Path with PS 5.1-compatible syntax |
| `3f3dc3c` | fix: skip repo clone if exists, auto-remove existing container |

## Evaluation Runs

### Run 1 — microsoft__BCApps-5633 (2026-04-08)

| Metric | Value |
|--------|-------|
| Model | claude-sonnet-4-6 |
| Agent | al-developer-bench |
| Config | altool MCP + custom instructions + skills |
| Build | ✅ |
| Resolved | ❌ |
| Time | 697s |
| Turns | 58 |
| Tokens | ~3M prompt / ~24K completion |
| Result file | `notebooks/result/bug-fix/aldc-sonnet-4-6/microsoft__BCApps-5633.jsonl` |

**Analysis**: The agent added `supportedActions` to GraphQL queries and created a `"Third Party"` boolean field on `FulfillmentOrderHeader`. However, the test validates using local BC data (`ShopLocation."Is Fulfillment Service"`) not GraphQL API data, so the agent's approach didn't match the test expectations.

## Pending

- [ ] Run remaining BCApps entries: 4822, 4699, 4766
- [ ] Compare baseline vs ALDC scenarios
- [ ] Run BCApps-5633 with `-Agent copilot` once Copilot CLI is auth'd on the VM
- [ ] Consider ADO access for the 97 internal entries
- [ ] Analyze results in notebook
- [ ] Validate that the new `aldc_evidence` and `aldc_usage` blocks appear in the next .jsonl

## Notes

- Only 4/101 dataset entries accessible without ADO access (microsoft/BCApps)
- VM must be deallocated when not in use: `az vm deallocate --resource-group rg-bcbench --name vm-bcbench`
- Always use `pwsh.exe` on VM (default PS is 5.1, scripts require PS 7+)

## Verification — how to confirm ALDC actually loaded in a run

Every result `.jsonl` written after commit `9ed6d41` includes two new blocks
under `experiment.aldc_evidence` and `metrics.aldc_usage`.

**Setup evidence (`experiment.aldc_evidence`)** — proves what was placed in
the testbed before the agent started:

```jsonc
"aldc_evidence": {
  "target_dir": ".claude",            // or ".github" for Copilot
  "agent_flag": "al-developer-bench", // what was passed via --agent=
  "rules_inlined": true,
  "rules_inlined_count": 8,           // 8 coding standards inlined into CLAUDE.md
  "paths_rewritten": true,            // .github/ -> .claude/ rewrite fired
  "files": [
    {"path": "CLAUDE.md", "sha256": "...", "bytes": 4231},
    {"path": "agents/al-developer-bench.md", "sha256": "...", "bytes": 6012},
    {"path": "skills/skill-testing/SKILL.md", "sha256": "...", "bytes": 2145},
    ...
  ]
}
```

If `files` is empty or `rules_inlined: false`, ALDC did not load — investigate.

**Usage evidence (`metrics.aldc_usage`)** — proves what the model actually
exercised during the run:

```jsonc
"aldc_usage": {
  "skills_invoked": {"skill-testing": 2, "skill-api": 1},
  "subagents_invoked": {"al-planning-subagent": 1},
  "custom_agent_confirmed": true
}
```

`custom_agent_confirmed: false` is a red flag — the agent file was on disk
but the host never loaded it. `skills_invoked: {}` is normal for simple
bug-fix tasks but suspicious for test-generation runs with `al-conductor-bench`.

## Running scenarios one at a time (avoiding API overload)

If the Anthropic API returns `overloaded_error` during a back-to-back
`-CompareAll` run, you can either:

### Option A — Automatic pause between scenarios

Let the script run all 3 scenarios back to back with a cooldown between each:

```powershell
cd C:\bcbench
.\scripts\Setup-ALDCEvaluation.ps1 `
    -InstanceId "microsoft__BCApps-5633" `
    -CompareAll `
    -PauseBetweenScenarios 180 `
    -SkipContainerSetup -SkipRepoClone -RepoPath "C:\bcbench\testbed"
```

`-PauseBetweenScenarios 180` inserts a 3-minute `Start-Sleep` between
scenarios. Try 120-300 seconds depending on how aggressive the overload
is. `-CompareBaseline` also honors this flag.

### Option B — Full manual control, one scenario per invocation

Run each scenario as a separate top-level command. You decide when to fire
the next one (e.g. wait until the previous finishes, check the API is
responding, then paste the next command). This is the safest option when
the API is really flaky.

```powershell
cd C:\bcbench

# --- Scenario 1/3: Baseline (no ALDC) ---
.\scripts\Setup-ALDCEvaluation.ps1 `
    -InstanceId "microsoft__BCApps-5633" `
    -Scenario baseline `
    -SkipContainerSetup -SkipRepoClone -RepoPath "C:\bcbench\testbed"

# --- Manual pause: wait ~3 minutes (or until the API feels healthy) ---

# --- Scenario 2/3: ALDC + al-developer-bench ---
.\scripts\Setup-ALDCEvaluation.ps1 `
    -InstanceId "microsoft__BCApps-5633" `
    -Scenario aldc-developer `
    -SkipContainerSetup -SkipRepoClone -RepoPath "C:\bcbench\testbed"

# --- Manual pause: wait ~3 minutes ---

# --- Scenario 3/3: ALDC + al-conductor-bench (TDD orchestration) ---
.\scripts\Setup-ALDCEvaluation.ps1 `
    -InstanceId "microsoft__BCApps-5633" `
    -Scenario aldc-conductor `
    -SkipContainerSetup -SkipRepoClone -RepoPath "C:\bcbench\testbed"
```

Each invocation:
- Reuses the same testbed and BC container (no re-clone, no rebuild)
- Mutates `config.yaml` to the target scenario, runs the eval, then
  restores `config.yaml` to its committed state
- Writes its result to a dedicated output directory:
  - `baseline` → `evaluation_results_baseline/...`
  - `aldc-developer` → `evaluation_results_aldc_al_developer_bench/...`
  - `aldc-conductor` → `evaluation_results_aldc_al_conductor_bench/...`

After all three finish, aggregate and compare:

```powershell
uv run bcbench result aggregate --input-dir evaluation_results_baseline
uv run bcbench result aggregate --input-dir evaluation_results_aldc_al_developer_bench
uv run bcbench result aggregate --input-dir evaluation_results_aldc_al_conductor_bench
```

## Running with GitHub Copilot CLI

Copilot CLI is installed by `Setup-VM-Phase2.ps1` step 8. Before any
`-Agent copilot` run, authenticate once interactively:

```powershell
copilot auth login
```

Then launch evaluation exactly like with Claude, just swap the agent:

```powershell
.\scripts\Setup-ALDCEvaluation.ps1 `
    -InstanceId "microsoft__BCApps-5633" `
    -Agent copilot `
    -SkipContainerSetup -SkipRepoClone -RepoPath "C:\bcbench\testbed"
```

The same ALDC machinery runs (rules inlined into `copilot-instructions.md`,
skills/agents copied to `.github/`), and the result `.jsonl` will include
the same `aldc_evidence` + `aldc_usage` blocks for direct comparison
against Claude runs.

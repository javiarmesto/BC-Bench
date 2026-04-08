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
- [ ] Consider ADO access for the 97 internal entries
- [ ] Analyze results in notebook

## Notes

- Only 4/101 dataset entries accessible without ADO access (microsoft/BCApps)
- VM must be deallocated when not in use: `az vm deallocate --resource-group rg-bcbench --name vm-bcbench`
- Always use `pwsh.exe` on VM (default PS is 5.1, scripts require PS 7+)

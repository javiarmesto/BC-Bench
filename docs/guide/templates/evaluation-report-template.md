# Evaluation Report: [Instance ID or Description]

<!--
Template for documenting BC-Bench evaluation results.
Fill in the sections below after each evaluation run.
Guide reference: docs/guide/05-resultados-y-analisis.md
-->

## Metadata

| Field | Value |
|-------|-------|
| **Date** | YYYY-MM-DD |
| **BC-Bench Version** | 0.4.0 |
| **Instance(s)** | microsoft__BCApps-XXXX |
| **Category** | bug-fix / test-generation |
| **BC Version** | XX.X |

## Agent Configuration

| Parameter | Value |
|-----------|-------|
| **Agent** | Claude Code / Copilot CLI / mini-bc-agent |
| **Model** | claude-sonnet-4-6 |
| **Custom Instructions** | Yes / No |
| **Skills Enabled** | Yes / No (list if partial) |
| **Custom Agent** | al-developer-bench / al-conductor-bench / al-bugfix-firstline / None |
| **AL MCP** | Yes / No |
| **MCP Servers** | altool, mslearn |

## Results

### Single Instance

| Instance | Resolved | Build | Turns | Time (s) | Tokens (K) |
|----------|:--------:|:-----:|------:|---------:|-----------:|
| BCApps-XXXX | ? | ? | -- | -- | -- |

### Multi-Scenario Comparison

| Scenario | Resolved | Build | Turns | Time (s) | Tokens (K) |
|----------|:--------:|:-----:|------:|---------:|-----------:|
| Baseline | ? | ? | -- | -- | -- |
| + Instructions + Skills + Agent | ? | ? | -- | -- | -- |
| + Conductor (TDD) | ? | ? | -- | -- | -- |

## Observations

### What worked

- 

### What failed

- 

### Failure category (if applicable)

<!--
Common failure categories:
1. Wrong file identified
2. Correct file, wrong fix
3. Correct diagnosis, syntax error
4. Timeout (agent looped)
5. Build failure (compilation error in patch)
6. Test not covering the actual fix
7. Partial fix (some tests pass, some fail)
-->

- 

## Conclusions

- 

## Reproduction

```powershell
# Command used to generate these results
.\scripts\Setup-ALDCEvaluation.ps1 `
  -InstanceId "microsoft__BCApps-XXXX" `
  -Scenario aldc-developer `
  -Agent claude `
  -Model claude-sonnet-4-6 `
  -Category bug-fix
```

## Artifacts

- Result JSONL: `evaluation_results/{run_id}/microsoft__BCApps-XXXX.jsonl`
- Summary JSON: `evaluation_results/{run_id}/evaluation_summary.json`
- Agent log: `evaluation_results/{run_id}/claude_debug.log`

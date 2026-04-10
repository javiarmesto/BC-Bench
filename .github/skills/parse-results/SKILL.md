# Parse BC-Bench Results

You are working with the BC-Bench evaluation pipeline. Your task is to read JSONL result files and produce a structured summary.

## Result file locations
Result files live in `notebooks/result/bug-fix/<scenario-dir>/<instance_id>.jsonl`.
Each line is a JSON object. Read only the **first line** of each file.

Key fields to extract:
- `instance_id` — benchmark entry
- `resolved` — boolean, did the agent pass all FAIL_TO_PASS tests
- `build` — boolean, did the code compile
- `metrics.turn_count` — number of agent turns
- `metrics.execution_time` — seconds
- `metrics.prompt_tokens` + `metrics.completion_tokens` → total tokens
- `generated_patch` — the diff the agent produced (check length in lines)

## Scenario directories → labels
| Directory | Label |
|-----------|-------|
| `claude-baseline-sonnet-4-6` | Claude / Baseline |
| `claude-aldc-al-developer-bench-sonnet-4-6` | Claude / ALDC Developer |
| `claude-aldc-al-conductor-bench-sonnet-4-6` | Claude / ALDC Conductor |
| `copilot-baseline-sonnet-4-6` | Copilot / Baseline |
| `copilot-aldc-al-developer-bench-sonnet-4-6` | Copilot / ALDC Developer |
| `copilot-aldc-al-conductor-bench-sonnet-4-6` | Copilot / ALDC Conductor |

## Output format
Produce a markdown table with columns:
`Instance | Agent | Scenario | Resolved | Build | Turns | Time (s) | Tokens (K)`

Group rows by Instance, then by Agent+Scenario.
At the bottom add a resolve rate per scenario: `X/N resolved`.

## Instructions
1. List all `.jsonl` files in the result directories using `grep_search` or `file_search`
2. For each file, read first line and extract the fields above
3. Build the table — use ✅/❌ for boolean fields
4. Highlight any instance where `resolved=true` in bold row (use `**`)

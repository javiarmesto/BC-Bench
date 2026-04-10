# Query BC-Bench Dataset

You are working with `dataset/bcbench.jsonl`. Each line is a JSON entry representing one benchmark task.

## Key fields
| Field | Description |
|-------|-------------|
| `instance_id` | Unique ID, format `owner__repo-number` |
| `repo` | `microsoft/BCApps` or `microsoftInternal/NAV` |
| `environment_setup_version` | BC version, e.g. `27.0`, `27.2` |
| `patch` | Gold patch (unified diff) |
| `FAIL_TO_PASS` | Tests that must pass after fix |
| `PASS_TO_PASS` | Tests that must stay passing |
| `problem_statement` | Bug description |

## Common queries

### Find entries by BC version
Read `dataset/bcbench.jsonl` line by line, parse JSON, filter where `environment_setup_version == "X.Y"`.

### Find small patches (≤ N lines)
Count lines in `patch` field that start with `+` or `-` (excluding `+++`/`---` headers).

### List accessible instances
Instances with `repo == "microsoft/BCApps"` are publicly accessible (no ADO required).

### Find pilot candidates (BC 27.0, small patch)
Filter: `environment_setup_version == "27.0"` AND patch_lines ≤ 15 AND `repo == "microsoftInternal/NAV"`

## NAV 27.0 pilot instances (already identified)
- `microsoftInternal__NAV-213629`
- `microsoftInternal__NAV-227358`
- `microsoftInternal__NAV-217974`
- `microsoftInternal__NAV-220314`
- `microsoftInternal__NAV-224009`

## Instructions
When asked to query the dataset:
1. Use `read_file` on `dataset/bcbench.jsonl` in chunks (it is large)
2. Parse each line as JSON
3. Apply the requested filter
4. Return a table: `Instance | Repo | BC Version | Patch Lines | FAIL_TO_PASS count`

# Trajectory Analysis

You are analyzing BC-Bench agent evaluation trajectories to understand agent behavior — specifically **why** an agent failed to resolve a bug.

## Trajectory file locations
On the VM: `C:\bcbench\<eval_dir>\<subdir>\<instance_id>.traj.json`
Where `subdir` is `claude_code_test_run` or `copilot_test_run`.

## Trajectory structure
A trajectory is a JSON object with a `trajectory` array. Each entry has:
- `role`: `user` or `assistant`
- `content`: text or array of tool-use blocks
- Tool use blocks have `type`, `name`, `input` (for tool calls) or `output` (for results)

## What to look for

### For conductor agents (`aldc-conductor`)
The conductor has 3 phases: Planning → Implementation → Review.
In the **Planning** phase, look for:
- Which files the agent explored (tool: `read_file`, `grep_search`, `file_search`)
- What file(s) were identified as the target for modification
- Compare against the gold patch file (from `dataset/bcbench.jsonl` → `patch` field)

**Known bug (BCApps-5633):** Conductor goes to `ShpfyGQLFFOrdersFromOrder.Codeunit.al` (wrong).
Gold patch is in `ShpfyExportShipments.Codeunit.al`.

### For developer agents and baseline
- Did the agent find the right file?
- Did the agent run the failing test before coding?
- Was the patch syntactically valid AL?

## Output format
Produce a structured summary:
```
## Trajectory Summary: <instance_id> / <scenario>

### Phase breakdown
- Planning: <N turns, files explored, target file identified>
- Implementation: <N turns, files modified>
- Review/Commit: <N turns>

### Key deviation
<1-2 sentences: where the agent went wrong and why>

### First wrong decision
Turn N: <description of the wrong tool call or reasoning>

### Comparison with gold patch
- Gold file: <filename>
- Agent file: <filename>
- Match: ✅ / ❌
```

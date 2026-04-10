# Fix Conductor Agent Instructions

## Context
BC-Bench evaluates agents on Business Central (AL) bug-fix tasks. The **conductor** agent
(`al-conductor-bench`) orchestrates Planning → Implementation → Review subagents.

**Confirmed bug:** On bug-fix tasks, the Planning phase explores speculatively (follows type
references, GraphQL queries, etc.) instead of starting from the FAIL_TO_PASS test. This leads
the conductor to modify the wrong file.

**Observed on BCApps-5633:**
- Wrong: `ShpfyGQLFFOrdersFromOrder.Codeunit.al` (found via GraphQL exploration)
- Correct: `ShpfyExportShipments.Codeunit.al` (imported by the FAIL_TO_PASS test)

## Files to read first
1. `src/bcbench/agent/shared/instructions/microsoft-BCApps/agents/al-conductor-bench.md` — current conductor instructions
2. `dataset/bcbench.jsonl` — look at `FAIL_TO_PASS` field structure for BCApps-5633

## Task
Modify the **Planning section** of `al-conductor-bench.md` to add a **bug-fix mode** guard:

### Design principles
- The FAIL_TO_PASS test is the single source of truth for which file to change
- The planning agent must read the failing test **before** any other exploration
- The test's `using`/`codeunit` references directly identify the target object
- Speculative exploration (following type chains, searching by keyword) is forbidden until the test-identified file has been read

### What to add
A new `## Bug-Fix Mode` section in the Planning phase with:
1. **Trigger**: if `problem_statement` contains words like "error", "fix", "wrong", "incorrect", "fails", "bug" OR if `FAIL_TO_PASS` list is non-empty
2. **Step 1**: Read each test in `FAIL_TO_PASS` — identify the `codeunit` under test
3. **Step 2**: Search for that codeunit in the repo — this is the **only candidate file**
4. **Step 3**: Read the candidate file and understand the failing assertion
5. **Step 4**: Only then proceed with the normal implementation plan
6. Do NOT explore other files until Step 3 is complete

### Quality bar
- The instruction must be unambiguous — a model following it mechanically should find the right file
- Keep it concise (< 20 lines) — the conductor already has long instructions
- Use imperative language ("Read X before Y", "Do not Z until W")
- After editing, verify the section integrates naturally with the existing Planning flow

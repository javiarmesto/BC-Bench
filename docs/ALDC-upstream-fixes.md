# ALDC Upstream Issues — Report for the AL Development Collection maintainers

During the integration of ALDC into BC-Bench for automated evaluation, we
discovered several issues that prevent parts of the framework from loading
correctly when the agents run outside of the VS Code Copilot Chat host (e.g.
in Claude Code CLI, GitHub Copilot CLI, or any other agent runtime that only
honors the standard `.claude/` / `.github/` conventions).

This document lists the issues so that they can be fixed upstream in the
canonical ALDC repository. BC-Bench applies local workarounds to keep the
evaluation meaningful, but those workarounds shouldn't be permanent.

---

## Issue 1 — Broken internal links in `rules/al-guidelines.md`

**File**: `rules/al-guidelines.md`

**Problem**: The "Context Loading" section links to sibling rule files using
the `.instructions.md` suffix, but the actual files on disk are named without
the `.instructions.` segment:

```markdown
- [AL Code Style Guidelines](./al-code-style.instructions.md) - Code structure and formatting
- [AL Naming Conventions](./al-naming-conventions.instructions.md) - Consistent naming patterns
- [AL Performance Guidelines](./al-performance.instructions.md) - Optimization best practices
- [AL Error Handling](./al-error-handling.instructions.md) - Error patterns and telemetry
- [AL Events Guidelines](./al-events.instructions.md) - Event-driven development
- [AL Testing Guidelines](./al-testing.instructions.md) - Test implementation patterns
```

Every link points at a file that does not exist (`al-code-style.md` exists,
`al-code-style.instructions.md` does not).

**Fix**: Drop the `.instructions` segment:

```markdown
- [AL Code Style Guidelines](./al-code-style.md) - Code structure and formatting
- [AL Naming Conventions](./al-naming-conventions.md) - Consistent naming patterns
- [AL Performance Guidelines](./al-performance.md) - Optimization best practices
- [AL Error Handling](./al-error-handling.md) - Error patterns and telemetry
- [AL Events Guidelines](./al-events.md) - Event-driven development
- [AL Testing Guidelines](./al-testing.md) - Test implementation patterns
```

**Impact**: Any agent or reader that follows the links hits a 404. For VS
Code Copilot this probably does not matter because the files are auto-applied
via frontmatter, but for any documentation browser or any agent that tries to
load the referenced files it is a broken reference.

BC-Bench has already applied this fix locally in its ALDC copies so that the
evaluation works.

---

## Issue 2 — `rules/` are invisible outside VS Code Copilot

**Files**: `rules/al-*.md`

**Problem**: Every rule file declares its auto-apply scope via a custom
frontmatter key:

```yaml
---
paths:
  - "**/*.al"
description: "..."
---
```

This is not a standard convention. It only works because the VS Code Copilot
Chat host knows how to interpret `paths:` (or `applyTo:` in newer builds) and
auto-applies the rule body whenever the user is editing a matching file.

Runtimes that do NOT know about this convention:

- **Claude Code CLI** — only auto-loads `.claude/CLAUDE.md`,
  `.claude/agents/*.md`, and `.claude/skills/*/SKILL.md`. It has no awareness
  of `.claude/rules/` at all.
- **GitHub Copilot CLI (non-VS Code)** — auto-loads
  `.github/copilot-instructions.md` but not `.github/rules/`.
- **Anything that consumes the files as plain documentation** — the rules
  look like orphaned files because nothing references them.

Additionally, `AGENTS.md` only mentions the rules in prose:

> See `rules/` directory for full coding standard definitions.

There is no `@include`, no explicit link followed at runtime, nothing that
would cause the rule bodies to reach the model.

**Consequence**: When ALDC runs under Claude Code or Copilot CLI without any
external help, the **8 coding standards are effectively dead code**. The
model never sees `al-code-style`, `al-naming-conventions`, `al-performance`,
`al-error-handling`, `al-events`, `al-testing`, `al-guidelines` or
`al-agent-toolkit`. The experiment measures "ALDC without the coding rules",
which is not what the framework advertises.

**Proposed fix options**:

1. **Inline the rules into `AGENTS.md`**. Append every rule body as a trailing
   "Coding Rules (auto-loaded)" section to the canonical instructions file.
   This is what BC-Bench does at copy time. Pro: universal, every runtime
   sees the rules. Con: AGENTS.md grows large.

2. **Adopt `@include` or a similar directive in `AGENTS.md`**. Requires
   changes in all hosts to honor the directive, so probably not realistic.

3. **Convert each rule to a Claude Code / Copilot CLI skill**. Rename
   `rules/al-code-style.md` to `skills/al-code-style/SKILL.md` with proper
   frontmatter (`name`, `description`). Pro: discoverable by standard
   conventions. Con: skills are invoked on demand, rules should be always-on
   — this subtly changes the framework semantics.

4. **Document the host requirement explicitly**. State in the ALDC README
   that the rules only load under VS Code Copilot Chat, and that other hosts
   must use a loader script. This makes the limitation visible.

BC-Bench uses option 1 as a runtime workaround: during testbed setup we
inline each rule into `CLAUDE.md` (for Claude Code) or
`copilot-instructions.md` (for Copilot CLI). See
`src/bcbench/operations/instruction_operations.py:_inline_rules_into_root_instructions`.

---

## Issue 3 — Agents hardcode `.github/` paths even in cross-host scenarios

**Files**: `agents/al-developer-bench.md`, `agents/al-conductor-bench.md`
(and their non-bench variants)

**Problem**: The agent markdown bodies contain 15+ hardcoded `.github/plans/`
and `.github/skills/` references. Examples from `al-conductor-bench.md`:

```
Write Plan File: Once approved, write the plan to `.github/plans/<task-name>/<task-name>-plan.md`.
Load relevant domain skills from .github/skills/ based on phase domain
Create Planning Completion File: Write `.github/plans/<task-name>/<task-name>-phase-1-complete.md`
Before starting orchestration, ALWAYS check for existing context in `.github/plans/`
```

When the same agent file is copied into `.claude/agents/` for a Claude Code
run, these paths are wrong:

- `.github/plans/` does not exist in the testbed at all (nothing creates it).
- `.github/skills/` does not exist either; the skills are under `.claude/skills/`.

For `al-developer-bench` this is mostly cosmetic: skills are still
auto-discovered by Claude Code from `.claude/skills/`, so the prose is
misleading but the mechanism works. But for `al-conductor-bench` it is a
functional bug: the orchestrator is instructed to write plan files and phase
completion files to `.github/plans/<task-name>/...`. Under Claude Code that
target directory does not exist, so the entire TDD workflow (plan → phase
complete → memory append → final report) writes to a path that breaks the
handoffs between phases.

**Proposed fix**: Do not hardcode a host-specific directory in agent
bodies. Use a host-agnostic placeholder (`{AGENT_HOME}/plans/`) and let each
host substitute its runtime directory (`.github/` for Copilot, `.claude/`
for Claude Code). If a placeholder isn't feasible, ship two variants of
each agent file: `al-conductor-bench.copilot.md` and
`al-conductor-bench.claude.md`, and pick the right one at copy time.

BC-Bench applies a runtime workaround: during setup we rewrite every
`.github/plans/` → `.claude/plans/` (and `.github/skills/` → `.claude/skills/`)
on the copied agent files when the target host is Claude Code. See
`src/bcbench/operations/instruction_operations.py:_rewrite_agent_paths`.

The upstream ALDC files are not modified by BC-Bench — only the testbed
copies are rewritten. But a host-agnostic upstream design would remove the
need for this workaround entirely.

---

## Summary

| Issue | Severity | BC-Bench workaround |
|-------|----------|---------------------|
| Broken `.instructions.md` links in al-guidelines.md | Low (docs) | Local edit in BC-Bench copies |
| `rules/*.md` not auto-loaded outside VS Code Copilot | **High** (feature-defeating) | Inline rules into CLAUDE.md/copilot-instructions.md at setup time |
| Agents hardcode `.github/` paths | **High** for conductor, Low for developer | Runtime `.github/` → `.claude/` rewrite for Claude runs |

All three workarounds are implemented in
`src/bcbench/operations/instruction_operations.py` and covered by tests in
`tests/test_custom_instructions.py`. They touch the testbed copies only; the
canonical ALDC files under
`src/bcbench/agent/shared/instructions/*/` are preserved (except the
`al-guidelines.md` link fix, which is a straight typo and was fixed in-place
in the local copy).

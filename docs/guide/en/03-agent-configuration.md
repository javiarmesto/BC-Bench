---
layout: default
title: "Part 3 — Configuration"
lang: en
---

# BC-Bench: Step-by-Step Guide

## Part 3 — Agent Configuration and Customization

---

## The Central Configuration File

Agent configuration for Claude Code and Copilot lives in:

```
src/bcbench/agent/shared/config.yaml
```

This file controls four key aspects:

1. **Prompts** — Instruction templates sent to the agent
2. **Instructions** — Custom instructions (CLAUDE.md / copilot-instructions.md)
3. **Skills** — Specialized knowledge modules loaded on demand
4. **Agents** — Custom agents with specific roles and behaviors

---

## 1. Prompt Templates

Templates define the base instruction the agent receives. They are configured under the `prompt:` key in `config.yaml`.

### Bug-Fix Template

```yaml
prompt:
  bug-fix-template: |
    You are working with a Business Central (AL) code repository at {{repo_path}}.

    Task: Fix the issue described below

    Important constraints:
    - Do NOT modify any testing logic or test files
    - Focus solely on fixing the reported issue
    {% if al_mcp %}
    - Do NOT try to run tests
    {% else %}
    - Do NOT try to build or run tests, just provide the code changes needed
    {% endif %}
    - Do NOT commit any changes to the repository
    - Focus on W1 localization

    Issue details:
    {{task}}
```

### Test-Generation Template

```yaml
prompt:
  test-generation-input: "both"  # "problem-statement", "gold-patch", or "both"

  test-generation-template: |
    You are working with a Business Central (AL) code repository at {{repo_path}}.

    Task: Generate ONE NEW test case that reproduce the issue described below
    ...
```

The `test-generation-input` field controls what information the agent receives:

| Mode | Agent sees | Use case |
|------|-----------|----------|
| `problem-statement` | Only the bug description | Test-driven development: write tests from requirements |
| `gold-patch` | Only the applied fix as unstaged changes | Verification: write tests that validate a known fix |
| `both` | Bug + fix | Full context for test generation |

### How to customize prompts

To try a different prompt, edit the template directly in `config.yaml`. Available variables:

| Variable | Content |
|----------|---------|
| `{{repo_path}}` | Path to the repository on the file system |
| `{{task}}` | Problem statement content (entry's README.md) |
| `{{project_paths}}` | List of affected project paths (if `include_project_paths: true`) |

**Example**: If you want the agent to have project path information:

```yaml
prompt:
  include_project_paths: true  # Changed from false to true
```

---

## 2. Custom Instructions

Custom instructions are markdown files copied into the repository before the agent runs. The agent reads them automatically as working context.

### How they work

```yaml
instructions:
  enabled: true   # Set to false for baseline evaluation
```

When `enabled: true`:
- **Claude Code**: `AGENTS.md` is copied to `{repo}/.claude/CLAUDE.md`
- **Copilot CLI**: `AGENTS.md` is copied to `{repo}/.github/copilot-instructions.md`

The source file is located at:

```
src/bcbench/agent/shared/instructions/{sanitized-repo}/AGENTS.md
```

Where `{sanitized-repo}` is the repo name with `/` replaced by `-` (e.g., `microsoft-BCApps`).

### Typical instruction content

The instructions include:
- Description of AL language and Business Central
- Agent routing (which agent to use based on intent)
- References to available skills
- Coding standards (naming, error handling, events, performance)

### How to create your own instructions

1. Create a directory for your repository:
   ```
   src/bcbench/agent/shared/instructions/my-org-MyRepo/
   ```

2. Create the `AGENTS.md` file with your instructions
3. BC-Bench will automatically rename it to the correct agent format

---

## 3. Skills

Skills are specialized knowledge modules copied to the agent's directory. Each skill is a folder with a `SKILL.md` file.

### Skills Configuration

```yaml
skills:
  enabled: true
  include:           # Whitelist: only copy these skills
    - skill-al-bugfix
    - skill-debug
    - skill-testing
    - skill-events
    - skill-performance
    - skill-api
    - skill-permissions
```

### Available Skills

| Skill | Purpose |
|-------|---------|
| `skill-al-bugfix` | Bug diagnosis and fix strategies for AL |
| `skill-debug` | Debugging techniques for Business Central |
| `skill-testing` | AL testing patterns (AAA, mocking, test isolation) |
| `skill-events` | BC event system and subscribers |
| `skill-performance` | Performance optimization in AL |
| `skill-api` | API development in Business Central |
| `skill-permissions` | Permission management and security |

Additional skills available but not included in the default whitelist:

| Skill | Purpose | Why excluded |
|-------|---------|-------------|
| `skill-copilot` | Copilot feature development | Not relevant for bug-fix |
| `skill-migrate` | Version migration | Not relevant for bug-fix |
| `skill-translate` | XLIFF and translations | Not relevant for bug-fix |
| `skill-pages` | AL page development | Not relevant for bug-fix |
| `skill-estimation` | PERT estimation | Not relevant for bug-fix |

### How to customize the skill list

To test with a different set of skills:

```yaml
skills:
  enabled: true
  include:
    - skill-al-bugfix
    - skill-debug
    # Add or remove skills here
```

To use ALL available skills, remove the `include` key:

```yaml
skills:
  enabled: true
  # No include = copy all skills
```

To disable skills entirely (evaluation without knowledge modules):

```yaml
skills:
  enabled: false
```

---

## 4. Custom Agents

Custom agents are markdown definitions that establish the agent's role, tools, and behavior.

### Agent Configuration

```yaml
agents:
  enabled: true
  name: al-developer-bench    # Default active agent
  profiles:
    al-developer-bench:
      include:
        - al-developer-bench.md
    al-conductor-bench:
      include:
        - al-conductor-bench.md
        - al-planning-subagent.md
        - al-implement-subagent.md
        - al-review-subagent.md
    al-bugfix-firstline:
      include:
        - al-bugfix-firstline.md
```

### Available Agents

#### al-developer-bench

**Type**: Direct tactical implementation
**File**: `agents/al-developer-bench.md`
**Tools**: Read, Glob, Grep, Write, Edit, Bash, Task, WebSearch, WebFetch
**Suggested model**: Sonnet
**Max turns**: 50

An implementation specialist that executes fixes directly. Does not delegate, does not do architectural design. Ideal for bug-fix.

#### al-conductor-bench

**Type**: Multi-agent TDD orchestration
**File**: `agents/al-conductor-bench.md` + 3 subagents
**Tools**: Read, Glob, Grep, Write, Edit, Bash, Task, WebSearch, WebFetch
**Suggested model**: Haiku (for the orchestrator)
**Max turns**: 50

Orchestrates a Planning -> Implementation -> Review cycle using delegated subagents:
- `al-planning-subagent.md` — Planning
- `al-implement-subagent.md` — Implementation
- `al-review-subagent.md` — Code review

Ideal for test-generation where TDD orchestration can improve quality.

#### al-bugfix-firstline

**Type**: Specialized autonomous diagnostics
**File**: `agents/al-bugfix-firstline.md`
**Tools**: Read, Glob, Grep, Write, Edit, Bash
**Max turns**: 40

A minimalist agent focused on producing the **minimum necessary patch**. Its workflow:
1. Read the test contract (non-negotiable, before anything else)
2. Trace data flow from test to production code
3. Diagnose the root cause
4. Apply the minimal fix

### How to change the active agent

Change the value of `agents.name`:

```yaml
agents:
  name: al-conductor-bench   # Previously: al-developer-bench
```

### How to create your own agent

1. Create a markdown file at:
   ```
   src/bcbench/agent/shared/instructions/{repo}/agents/my-agent.md
   ```

2. Use YAML frontmatter to define its properties:
   ```yaml
   ---
   name: My Specialized Agent
   description: >
     Description of what the agent does.
   tools: Read, Glob, Grep, Write, Edit, Bash
   model: sonnet
   maxTurns: 50
   ---
   ```

3. Write the agent instructions in the markdown body

4. Add it as a profile in `config.yaml`:
   ```yaml
   agents:
     name: my-agent
     profiles:
       my-agent:
         include:
           - my-agent.md
   ```

---

## 5. MCP Servers

MCP (Model Context Protocol) servers give the agent access to external tools during evaluation.

### Configured Servers

```yaml
mcp:
  servers:
    - name: "altool"      # AL Tool — AL compiler via MCP
      type: "stdio"
      command: "al"
      args: ["launchmcpserver", "--transport", "stdio",
             "--packagecachepath", "{{package_cache_path}}"]

    - name: "mslearn"     # Microsoft Learn — documentation
      type: "http"
      url: "https://learn.microsoft.com/api/mcp"
```

- **altool**: Activated with `--al-mcp`. Gives the agent access to the AL compiler for real-time compilation errors.
- **mslearn**: Official Microsoft Learn documentation. Always available (HTTP, no local dependencies).

### Adding a new MCP server

Uncomment or add servers in the `mcp.servers` section:

```yaml
    - name: "context7"
      type: "stdio"
      command: "npx"
      args: ["-y", "@upstash/context7-mcp@latest"]
```

> **Note**: `stdio` servers require the executable to be in the VM's PATH.

---

## Summary: What to Modify for Each Experiment

| What you want to test | Where to modify | Value |
|-----------------------|----------------|-------|
| Different LLM model | `--model` CLI flag | See model list |
| No instructions (baseline) | `config.yaml` > `instructions.enabled` | `false` |
| No skills | `config.yaml` > `skills.enabled` | `false` |
| Different skill set | `config.yaml` > `skills.include` | List of skills |
| No custom agent | `config.yaml` > `agents.enabled` | `false` |
| Different custom agent | `config.yaml` > `agents.name` | Agent name |
| With AL MCP | `--al-mcp` CLI flag | Present or absent |
| Different prompt | `config.yaml` > `prompt.bug-fix-template` | Your template |
| Different category | `--category` CLI flag | `bug-fix` or `test-generation` |

---

> **Next**: [Part 4 — Baseline Comparison and VM Scripts](04-baselines-and-vm-scripts.md)

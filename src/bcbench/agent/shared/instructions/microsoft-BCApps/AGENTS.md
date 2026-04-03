# Dynamics 365 Business Central (AL) Development

Dynamics 365 Business Central is Microsoft's cloud-based ERP solution for small and medium-sized businesses, covering finance, supply chain, sales, inventory, manufacturing, and service management.

**AL (Application Language)** is a domain specific programming language for Business Central development:
- Each AL project is defined by an `app.json` file at its root folder
- Apps are compiled into `.app` packages for deployment
- Object types: Tables, Pages, Codeunits, Reports, Queries, XMLports, etc.
- Extensibility through events and object (table/page/enum) extensions

---

# ALDC — AL Development Collection (v3.2.0)

> Skills-based, spec-driven, TDD-orchestrated development framework for Business Central.
> Architecture: **ALDC Core v1.1** — 4 agents + 11 skills + 6 workflows + 9 auto-applied coding standards.

## Core Principles

- **Extension-only development** — Never modify base application objects. Use tableextensions, pageextensions, event subscribers.
- **Human-in-the-Loop (HITL)** — All critical decisions require user confirmation before proceeding.
- **TDD / spec-driven** — Features follow: `spec.create` -> architecture -> test-plan -> implementation -> review.
- **Least privilege** — Generate only the minimum permissions required. Use XLIFF for all user-facing strings.

## Agent Routing

| Intent | Agent | What it does |
|--------|-------|-------------|
| Design, architecture, strategy | delegate to agent `al-architect` | Solution design, data modeling, integration strategy |
| Implement, code, debug, fix | delegate to agent `al-developer` | Tactical implementation with full AL tools |
| TDD orchestration (plan -> implement -> review -> commit) | delegate to agent `al-conductor` | Orchestrates planning, implementation, and review subagents |
| Estimate, size, propose | delegate to agent `al-presales` | PERT estimation, SWOT analysis, cost breakdown |

### Quick Routing

```
New feature (MEDIUM/HIGH)? -> al-architect -> al-spec.create -> al-conductor
New feature (LOW)?         -> al-spec.create -> al-developer
Bug fix / debugging?       -> al-developer
Architecture review?       -> al-architect
Full TDD cycle?            -> al-conductor
Project estimation?        -> al-presales
```

## Skills

11 composable knowledge modules loaded on-demand by agents (not invoked directly):

| Skill | Domain | Loaded by |
|-------|--------|-----------|
| skill-debug | Debugging, snapshot debugging | al-developer |
| skill-api | API pages, OData, REST | al-developer, al-architect |
| skill-copilot | AI features, PromptDialog | al-developer, al-architect |
| skill-events | Event subscribers, publishers | al-developer, al-architect |
| skill-permissions | Permission sets, XLIFF, security | al-developer |
| skill-pages | Page types, FastTabs, actions | al-developer |
| skill-migrate | BC version migration, upgrade codeunits | al-developer |
| skill-translate | XLF translation, NAB AL Tools | al-developer |
| skill-performance | CPU profiling, FlowField optimization | al-developer, al-architect |
| skill-testing | TDD, test strategy, AL Test Toolkit | al-architect, al-conductor |
| skill-estimation | PERT estimation, complexity scoring | al-presales |

### Skills Evidencing

Agents MUST declare which skills they loaded and which patterns they applied:
- **al-architect** -> `> **Skills applied**: skill-api, skill-events` at top of architecture.md
- **al-developer** -> `> **Skills loaded**: skill-debug (root cause analysis)` at start of response
- **al-conductor** -> `Skills Applied in This Phase` table in phase-complete.md

## Auto-Applied Coding Standards

Active automatically based on file type (no invocation needed):

**Always on `*.al`**: al-guidelines, al-code-style, al-naming-conventions, al-performance
**Context-activated**: al-error-handling (errors), al-events (events), al-testing (test files)

See `rules/` directory for full coding standard definitions.

## Complexity-Based Routing

| Level | Scope | Route |
|-------|-------|-------|
| **LOW** | Single phase, no integrations | al-spec.create -> al-developer |
| **MEDIUM** | 2-3 areas, internal integrations | al-architect -> al-spec.create -> al-conductor |
| **HIGH** | 4+ phases, external integrations | al-architect -> al-spec.create -> al-conductor |

Present the assessment and wait for user confirmation before proceeding.

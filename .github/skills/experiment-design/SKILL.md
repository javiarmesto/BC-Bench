# Experiment Design for BC-Bench Evaluation

## Goal
Determine whether the ALDC (AL Development Collection) custom instructions improve agent
resolve rates on Business Central bug-fix tasks, compared to a baseline (no custom instructions).

## Current data (as of April 2026)
| Scenario | BCApps-4822 | BCApps-5633 |
|----------|:-----------:|:-----------:|
| Claude Baseline | ✅ | ❌ |
| Claude ALDC Developer | ❌ | ❌ |
| Claude ALDC Conductor | ❌ | ❌ |
| Copilot Baseline | ❌ | ❌ |
| Copilot ALDC Developer | ❌ | ✅ |
| Copilot ALDC Conductor | ✅ | ❌ |

**Problem:** n=2 instances, n=1 run per cell → no statistical power. Cannot distinguish signal from noise.

## Planned expansion
5 NAV 27.0 instances (pilot): `NAV-213629`, `NAV-227358`, `NAV-217974`, `NAV-220314`, `NAV-224009`

## Your task
Design a minimal but statistically sound experiment. Address:

### 1. Minimum sample size
- What is the minimum n (instances) needed for 80% power to detect a 20 percentage point difference in resolve rate?
- What n for 15 pp? For 10 pp?
- Assume baseline resolve rate ≈ 0.3 (30%)
- Use appropriate test (Fisher's exact, proportion z-test, or bootstrap — justify your choice)
- Use simple language, not statistical jargon

### 2. Experiment structure
- How many instances per BC version group?
- Should we stratify by patch size (small ≤10 lines vs medium 11-20 vs large >20)?
- Should we run multiple trials per instance (pass@k)? What k?

### 3. Hypotheses to test
Define 3-4 falsifiable hypotheses, e.g.:
- H1: ALDC Developer improves resolve rate vs Baseline for Claude
- H2: Conductor has lower resolve rate than Developer on bug-fix tasks
- H3: Container reuse across instances does not affect resolve rate (control)

### 4. Confounds to control
List the main confounds and how to control for them:
- BC version differences
- Patch complexity
- Test isolation (container state)
- Model version drift

### 5. Recommended next steps
Given the current 7 instances (2 BCApps + 5 NAV pilot), what is the realistic power?
What is the minimum additional dataset needed to reach a publishable result?

## Output format
- Plain language explanation of statistical choices
- Table: n_instances → detectable_effect_size (at 80% power)
- Final recommendation: "Run X more instances to reach Y confidence"

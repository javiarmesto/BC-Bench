---
layout: default
title: "BC-Bench Guide"
---

# BC-Bench Guide

A practical step-by-step guide for evaluating coding agents on real **Microsoft Dynamics 365 Business Central** tasks using the [BC-Bench](https://github.com/microsoft/BC-Bench) framework.

Una guia practica paso a paso para evaluar agentes de codificacion sobre tareas reales de **Microsoft Dynamics 365 Business Central** usando el framework [BC-Bench](https://github.com/microsoft/BC-Bench).

---

## Choose your language / Elige tu idioma

<div style="display: flex; gap: 2rem; margin: 2rem 0; flex-wrap: wrap;">
  <a href="en/01-introduction" style="display: block; padding: 2rem; border: 2px solid var(--border); border-radius: 8px; text-align: center; flex: 1; min-width: 200px; text-decoration: none;">
    <strong style="font-size: 1.5rem;">English</strong><br>
    <span>Start the guide in English</span>
  </a>
  <a href="es/01-introduccion" style="display: block; padding: 2rem; border: 2px solid var(--border); border-radius: 8px; text-align: center; flex: 1; min-width: 200px; text-decoration: none;">
    <strong style="font-size: 1.5rem;">Espanol</strong><br>
    <span>Empezar la guia en espanol</span>
  </a>
</div>

---

## What is BC-Bench?

BC-Bench is an **open-source benchmarking framework** by Microsoft for evaluating coding agents (Claude Code, GitHub Copilot CLI, and others) on real-world Business Central (AL) development tasks. It includes:

- **101 real bugs** from the BCApps and NAV repositories
- **Automated evaluation** with compilation and test execution in BC containers
- **Configurable agents** with custom instructions, skills, and MCP servers
- **Statistical metrics** including pass rate, bootstrap CI, and pass@k

## Guide Contents

| # | English | Espanol |
|---|---------|---------|
| 1 | [Introduction](en/01-introduction) | [Introduccion](es/01-introduccion) |
| 2 | [Setup & First Evaluation](en/02-setup-and-first-evaluation) | [Setup y Primera Evaluacion](es/02-setup-y-primera-evaluacion) |
| 3 | [Agent Configuration](en/03-agent-configuration) | [Configuracion de Agentes](es/03-configuracion-de-agentes) |
| 4 | [Baselines & VM Scripts](en/04-baselines-and-vm-scripts) | [Baselines y Scripts VM](es/04-baselines-y-scripts-vm) |
| 5 | [Results & Analysis](en/05-results-and-analysis) | [Resultados y Analisis](es/05-resultados-y-analisis) |

## Quick Start

```bash
# Install BC-Bench
gh repo fork microsoft/BC-Bench --clone && cd BC-Bench
uv python install && uv sync --all-groups

# Explore the dataset
uv run bcbench dataset list
uv run bcbench dataset view microsoft__BCApps-4822

# Run your first evaluation (patch only, no container needed)
uv run bcbench run claude microsoft__BCApps-4822 --category bug-fix --model claude-sonnet-4-6
```

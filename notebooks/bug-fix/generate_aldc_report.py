"""Generate standalone HTML report for ALDC vs Baseline analysis.

Usage:
    uv run python notebooks/bug-fix/generate_aldc_report.py
"""

import json
import sys
from pathlib import Path

import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots

NOTEBOOKS_DIR = Path(__file__).parent
RESULT_DIR = NOTEBOOKS_DIR.parent / "result" / "bug-fix"
OUTPUT_HTML = NOTEBOOKS_DIR / "aldc-comparison-full.html"

INSTANCES = ["microsoft__BCApps-5633", "microsoft__BCApps-4822", "microsoft__BCApps-4699"]
INSTANCE_LABELS = {"microsoft__BCApps-5633": "BCApps-5633", "microsoft__BCApps-4822": "BCApps-4822", "microsoft__BCApps-4699": "BCApps-4699"}
INSTANCE_DIFFICULTY = {"microsoft__BCApps-5633": "Hard", "microsoft__BCApps-4822": "Medium", "microsoft__BCApps-4699": "Easy"}
SCENARIOS = ["Baseline", "ALDC+developer", "ALDC+conductor"]
AGENTS = ["Claude Code", "Copilot"]
MODELS = ["sonnet-4-6", "opus-4-6"]

SETUP_MAP = {
    ("Claude Code", "sonnet-4-6", "Baseline"): "claude-baseline-sonnet-4-6",
    ("Claude Code", "sonnet-4-6", "ALDC+developer"): "claude-aldc-al-developer-bench-sonnet-4-6",
    ("Claude Code", "sonnet-4-6", "ALDC+conductor"): "claude-aldc-al-conductor-bench-sonnet-4-6",
    ("Claude Code", "opus-4-6", "Baseline"): "claude-baseline-opus-4-6",
    ("Claude Code", "opus-4-6", "ALDC+developer"): "claude-aldc-al-developer-bench-opus-4-6",
    ("Claude Code", "opus-4-6", "ALDC+conductor"): "claude-aldc-al-conductor-bench-opus-4-6",
    ("Copilot", "sonnet-4-6", "Baseline"): "copilot-baseline-sonnet-4-6",
    ("Copilot", "sonnet-4-6", "ALDC+developer"): "copilot-aldc-al-developer-bench-sonnet-4-6",
    ("Copilot", "sonnet-4-6", "ALDC+conductor"): "copilot-aldc-al-conductor-bench-sonnet-4-6",
    ("Copilot", "opus-4-6", "Baseline"): "copilot-baseline-opus-4-6",
    ("Copilot", "opus-4-6", "ALDC+developer"): "copilot-aldc-al-developer-bench-opus-4-6",
    ("Copilot", "opus-4-6", "ALDC+conductor"): "copilot-aldc-al-conductor-bench-opus-4-6",
}


def load_aldc_results() -> pd.DataFrame:
    rows = []
    for (agent, model, scenario), folder_name in SETUP_MAP.items():
        folder = RESULT_DIR / folder_name
        if not folder.exists():
            continue
        for instance_id in INSTANCES:
            jsonl_file = folder / f"{instance_id}.jsonl"
            if not jsonl_file.exists():
                continue
            for run_idx, line in enumerate(jsonl_file.read_text(encoding="utf-8").splitlines()):
                if not line.strip():
                    continue
                data = json.loads(line)
                m = data.get("metrics", {})
                exp = data.get("experiment", {})
                au = m.get("aldc_usage", {})
                ev = exp.get("aldc_evidence", {})
                rows.append({
                    "agent": agent, "model": model, "scenario": scenario,
                    "instance_id": instance_id,
                    "instance": INSTANCE_LABELS.get(instance_id, instance_id),
                    "difficulty": INSTANCE_DIFFICULTY.get(instance_id, "?"),
                    "run_idx": run_idx,
                    "resolved": data.get("resolved", False),
                    "build": data.get("build", False),
                    "turns": m.get("turn_count"),
                    "time_s": m.get("execution_time"),
                    "prompt_tokens": m.get("prompt_tokens"),
                    "completion_tokens": m.get("completion_tokens"),
                    "tool_usage": m.get("tool_usage"),
                    "agent_confirmed": au.get("custom_agent_confirmed"),
                    "skills_invoked": au.get("skills_invoked", {}),
                    "subagents_invoked": au.get("subagents_invoked", {}),
                    "rules_count": ev.get("rules_inlined_count"),
                    "aldc_files_count": len(ev.get("files", [])),
                })
    return pd.DataFrame(rows)


# ── 1. Heatmap ──────────────────────────────────────────────────────────────
def build_heatmap(df: pd.DataFrame) -> go.Figure:
    row_labels, col_labels, z_matrix, text_matrix = [], [], [], []
    for scenario in SCENARIOS:
        for agent in AGENTS:
            col_labels.append(f"{scenario}<br><sub>{agent}</sub>")
    for inst_id in INSTANCES:
        inst_label = INSTANCE_LABELS[inst_id]
        diff = INSTANCE_DIFFICULTY[inst_id]
        for model in MODELS:
            row_labels.append(f"{inst_label} ({diff})<br><sub>{model}</sub>")
            row_z, row_text = [], []
            for scenario in SCENARIOS:
                for agent in AGENTS:
                    s = df[(df["instance_id"] == inst_id) & (df["model"] == model) &
                           (df["scenario"] == scenario) & (df["agent"] == agent)]
                    if s.empty:
                        row_z.append(-1); row_text.append("—")
                    else:
                        n, nr = len(s), int(s["resolved"].sum())
                        avg_tok = s["prompt_tokens"].mean()
                        if n == 1:
                            row_z.append(1.0 if nr else 0.0)
                            row_text.append(f"{'✅' if nr else '❌'}<br>{avg_tok/1000:.0f}K")
                        else:
                            row_z.append(nr / n)
                            row_text.append(f"{nr}/{n}<br>{avg_tok/1000:.0f}K")
            z_matrix.append(row_z); text_matrix.append(row_text)

    z_norm = [[(v + 1) / 2 for v in row] for row in z_matrix]
    fig = go.Figure(data=go.Heatmap(
        z=z_norm, x=col_labels, y=row_labels,
        text=text_matrix, texttemplate="%{text}", textfont={"size": 13},
        colorscale=[[0, "#bdc3c7"], [0.25, "#e74c3c"], [0.5, "#e74c3c"],
                     [0.625, "#f39c12"], [0.75, "#f39c12"], [1, "#2ecc71"]],
        showscale=False,
        hovertemplate="<b>%{y}</b><br>%{x}<br>%{text}<extra></extra>",
    ))
    fig.update_layout(
        title="Resolution Heatmap: ALDC vs Baseline",
        height=480, width=1000,
        yaxis=dict(autorange="reversed", tickfont=dict(size=11)),
        xaxis=dict(tickfont=dict(size=10), side="top"),
        margin=dict(l=200, r=20, t=80, b=20),
    )
    return fig


# ── 2. Token overhead bars ──────────────────────────────────────────────────
def build_token_chart(df: pd.DataFrame) -> go.Figure:
    first = df[df["run_idx"] == 0]
    fig = make_subplots(rows=1, cols=3, shared_yaxes=True,
                        subplot_titles=[f"{INSTANCE_LABELS[i]} ({INSTANCE_DIFFICULTY[i]})" for i in INSTANCES])
    cmap = {True: "#2ecc71", False: "#e74c3c"}
    for ci, inst_id in enumerate(INSTANCES, 1):
        sub = first[first["instance_id"] == inst_id].copy()
        sub["label"] = sub["scenario"] + "<br>" + sub["agent"] + "<br><sub>" + sub["model"] + "</sub>"
        sub = sub.sort_values(["scenario", "agent", "model"])
        fig.add_trace(go.Bar(
            x=sub["label"], y=sub["prompt_tokens"] / 1000,
            marker_color=[cmap[r] for r in sub["resolved"]],
            text=[f"{'✅' if r else '❌'} {t/1000:.0f}K" for r, t in zip(sub["resolved"], sub["prompt_tokens"])],
            textposition="outside", textfont=dict(size=9), showlegend=False,
        ), row=1, col=ci)
    fig.update_layout(title="Prompt Tokens por configuracion (verde=resolved, rojo=failed)",
                      height=500, width=1200, yaxis_title="Prompt tokens (K)")
    return fig


# ── 3. Time & turns ─────────────────────────────────────────────────────────
def build_efficiency_chart(df: pd.DataFrame) -> go.Figure:
    first = df[df["run_idx"] == 0]
    fig = make_subplots(rows=1, cols=2, subplot_titles=["Turns", "Execution Time (s)"])
    scolors = {"Baseline": "#3498db", "ALDC+developer": "#e67e22", "ALDC+conductor": "#9b59b6"}
    for ci, (metric, _) in enumerate([("turns", "Turns"), ("time_s", "Time (s)")], 1):
        for scenario in SCENARIOS:
            sub = first[first["scenario"] == scenario].sort_values(["instance_id", "agent", "model"])
            labels = [f"{r['instance']}<br>{r['agent']}<br><sub>{r['model']}</sub>" for _, r in sub.iterrows()]
            fig.add_trace(go.Bar(
                x=labels, y=sub[metric], name=scenario, marker_color=scolors[scenario],
                text=[f"{'✅' if r else '❌'} {v:.0f}" for r, v in zip(sub["resolved"], sub[metric])],
                textposition="outside", textfont=dict(size=8), showlegend=(ci == 1),
            ), row=1, col=ci)
    fig.update_layout(title="Eficiencia por configuracion", height=500, width=1200, barmode="group",
                      legend=dict(orientation="h", yanchor="bottom", y=1.08))
    return fig


# ── 4. Summary table HTML ───────────────────────────────────────────────────
def build_summary_table(df: pd.DataFrame) -> str:
    first = df[df["run_idx"] == 0].copy()
    first["Resolved"] = first["resolved"].map({True: "✅", False: "❌"})
    first["Tokens (K)"] = (first["prompt_tokens"] / 1000).round(0).astype(int)
    first["Time (s)"] = first["time_s"].round(0).astype(int)
    cols = ["instance", "agent", "model", "scenario", "Resolved", "turns", "Time (s)", "Tokens (K)"]
    t = first[cols].sort_values(["instance", "model", "scenario", "agent"]).reset_index(drop=True)
    t.columns = ["Instance", "Agent", "Model", "Scenario", "Resolved", "Turns", "Time (s)", "Tokens (K)"]
    return t.to_html(index=False, classes="data-table", escape=False, border=0)


# ── 5. Overhead multiplier table ────────────────────────────────────────────
def build_overhead_table(df: pd.DataFrame) -> str:
    first = df[df["run_idx"] == 0]
    rows = []
    for inst_id in INSTANCES:
        for agent in AGENTS:
            for model in MODELS:
                bl = first[(first["instance_id"] == inst_id) & (first["agent"] == agent) &
                           (first["model"] == model) & (first["scenario"] == "Baseline")]
                if bl.empty:
                    continue
                bt = bl.iloc[0]["prompt_tokens"]
                br = bl.iloc[0]["resolved"]
                for sc in ["ALDC+developer", "ALDC+conductor"]:
                    al = first[(first["instance_id"] == inst_id) & (first["agent"] == agent) &
                               (first["model"] == model) & (first["scenario"] == sc)]
                    if al.empty:
                        continue
                    at = al.iloc[0]["prompt_tokens"]
                    ar = al.iloc[0]["resolved"]
                    ratio = at / bt if bt > 0 else float("inf")
                    delta = "same" if br == ar else ("improved" if ar else "regressed")
                    rows.append({
                        "Instance": INSTANCE_LABELS[inst_id], "Agent": agent, "Model": model,
                        "Scenario": sc, "Overhead": f"{ratio:.1f}x",
                        "Resolution": f"{'✅' if delta == 'improved' else '❌' if delta == 'regressed' else '='} {delta}",
                    })
    return pd.DataFrame(rows).to_html(index=False, classes="data-table", escape=False, border=0)


# ── 6. Evidence table ───────────────────────────────────────────────────────
def build_evidence_table(df: pd.DataFrame) -> str:
    aldc = df[(df["scenario"] != "Baseline") & (df["run_idx"] == 0)]
    rows = []
    for _, r in aldc.iterrows():
        sa = r["subagents_invoked"]
        rows.append({
            "Instance": r["instance"], "Agent": r["agent"], "Model": r["model"],
            "Scenario": r["scenario"],
            "Resolved": "✅" if r["resolved"] else "❌",
            "Agent Confirmed": "✅" if r["agent_confirmed"] else "❌",
            "Skills Invoked": len(r["skills_invoked"]) if r["skills_invoked"] else 0,
            "Subagents": ", ".join(sa.keys()) if sa else "—",
            "Rules": f"{r['rules_count']}/8" if r["rules_count"] else "—",
            "Files": r["aldc_files_count"],
        })
    return pd.DataFrame(rows).to_html(index=False, classes="data-table", escape=False, border=0)


# ── 7. Tool usage table ─────────────────────────────────────────────────────
def build_tool_table(df: pd.DataFrame) -> str:
    claude = df[(df["agent"] == "Claude Code") & (df["run_idx"] == 0) & (df["tool_usage"].apply(lambda x: bool(x)))]
    rows = []
    for _, r in claude.iterrows():
        tu = r["tool_usage"]
        rows.append({
            "Instance": r["instance"], "Model": r["model"], "Scenario": r["scenario"],
            "Resolved": "✅" if r["resolved"] else "❌",
            "Read": tu.get("Read", 0), "Grep": tu.get("Grep", 0), "Glob": tu.get("Glob", 0),
            "Edit": tu.get("Edit", 0), "Bash": tu.get("Bash", 0), "Agent": tu.get("Agent", 0),
        })
    return pd.DataFrame(rows).to_html(index=False, classes="data-table", escape=False, border=0) if rows else "<p>No tool usage data available.</p>"


# ── Assemble HTML ────────────────────────────────────────────────────────────
def generate_report():
    df = load_aldc_results()
    print(f"Loaded {len(df)} rows")

    heatmap = build_heatmap(df)
    tokens_chart = build_token_chart(df)
    efficiency_chart = build_efficiency_chart(df)
    summary_html = build_summary_table(df)
    overhead_html = build_overhead_table(df)
    evidence_html = build_evidence_table(df)
    tool_html = build_tool_table(df)

    html = f"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>ALDC vs Baseline — BC-Bench Results</title>
<script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>
<style>
  body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
         max-width: 1200px; margin: 0 auto; padding: 20px; color: #333; line-height: 1.6; }}
  h1 {{ border-bottom: 3px solid #2c3e50; padding-bottom: 10px; }}
  h2 {{ color: #2c3e50; margin-top: 40px; border-bottom: 1px solid #bdc3c7; padding-bottom: 5px; }}
  h3 {{ color: #34495e; }}
  .data-table {{ border-collapse: collapse; width: 100%; margin: 15px 0; font-size: 13px; }}
  .data-table th {{ background: #2c3e50; color: white; padding: 8px 12px; text-align: center; }}
  .data-table td {{ padding: 6px 12px; text-align: center; border-bottom: 1px solid #ecf0f1; }}
  .data-table tr:hover {{ background: #f8f9fa; }}
  .chart-container {{ margin: 20px 0; }}
  .finding {{ background: #f8f9fa; border-left: 4px solid #3498db; padding: 15px; margin: 15px 0; }}
  .finding.warning {{ border-left-color: #e67e22; }}
  .finding.critical {{ border-left-color: #e74c3c; }}
  .finding.positive {{ border-left-color: #2ecc71; }}
  .caveat {{ background: #fef9e7; border: 1px solid #f9e79f; padding: 12px; margin: 15px 0; border-radius: 4px; }}
  .metric-grid {{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px; margin: 20px 0; }}
  .metric-card {{ background: #f8f9fa; padding: 15px; border-radius: 8px; text-align: center; }}
  .metric-card .value {{ font-size: 28px; font-weight: bold; color: #2c3e50; }}
  .metric-card .label {{ font-size: 12px; color: #7f8c8d; text-transform: uppercase; }}
</style>
</head>
<body>

<h1>ALDC vs Baseline: BC-Bench Results</h1>
<p><strong>Date:</strong> 2026-04-10 &nbsp;|&nbsp;
   <strong>Instances:</strong> 3 (BCApps-5633, 4822, 4699) &nbsp;|&nbsp;
   <strong>Scenarios:</strong> Baseline, ALDC+developer, ALDC+conductor &nbsp;|&nbsp;
   <strong>Agents:</strong> Claude Code, Copilot &nbsp;|&nbsp;
   <strong>Models:</strong> sonnet-4-6, opus-4-6</p>

<div class="caveat">
  <strong>Caveat:</strong> ALDC es un framework HITL (Human-in-the-Loop) con validation gates, TDD y spec-driven development.
  En BC-Bench se testea <strong>solo la parte ejecutora</strong> en modo autonomo ("bench mode"), sin validaciones humanas.
  n=3 instancias — analisis exploratorio, sin significancia estadistica.
</div>

<div class="metric-grid">
  <div class="metric-card">
    <div class="value">{len(df)}</div>
    <div class="label">Total result rows</div>
  </div>
  <div class="metric-card">
    <div class="value">{df[df['run_idx']==0]['resolved'].mean()*100:.0f}%</div>
    <div class="label">Overall resolution rate</div>
  </div>
  <div class="metric-card">
    <div class="value">3-4x</div>
    <div class="label">ALDC token overhead</div>
  </div>
</div>

<h2>1. Resolution Heatmap</h2>
<p>Green = resolved. Red = failed. Gray = not tested. Yellow = partial (e.g., 1/2 runs passed).</p>
<div class="chart-container" id="heatmap"></div>

<h2>2. Summary Table</h2>
{summary_html}

<h2>3. Token Overhead</h2>
<div class="chart-container" id="tokens"></div>

<h3>3.1 Overhead Multiplier (ALDC / Baseline)</h3>
<p>Solo donde existen datos pareados (mismo agent + model + instance).</p>
{overhead_html}

<div class="finding warning">
  <strong>Hallazgo:</strong> El overhead medio de ALDC es 3.0-4.3x sobre baseline (developer y conductor respectivamente).
  Este coste es estructural: ~300KB de instrucciones + skills + reglas cargadas en contexto.
</div>

<h2>4. Efficiency: Turns & Time</h2>
<div class="chart-container" id="efficiency"></div>

<h2>5. The Blindness Problem / El Problema de la Ceguera</h2>
<p>ALDC despliega 32 archivos (~300KB) en <code>.claude/</code>. Pero no podemos verificar si el modelo
los lee, los procesa, o los ignora. Solo tenemos evidencia indirecta.</p>

{evidence_html}

<div class="finding critical">
  <strong>Skills:</strong> 0 invocaciones explicitas en {len(df[(df['scenario']!='Baseline') & (df['run_idx']==0)])} runs ALDC.
  Las 11 skills existen como archivos .md pero nunca se invocan via tool.
</div>

<div class="finding critical">
  <strong>Asimetria de subagentes:</strong> Claude Code: 0% subagent invocation.
  Copilot: 100% subagent invocation (incluso con developer agent, que no deberia orquestar).
  Los dos runners ejecutan la misma instruccion ALDC de manera fundamentalmente diferente.
</div>

<h2>6. Tool Usage (Claude Code only)</h2>
{tool_html}

<div class="finding">
  <strong>Dato contraintuitivo:</strong> Baseline explora <em>mas</em> que ALDC (Read+Grep+Glob),
  no menos. El ratio exploracion/edicion decrece con ALDC (11.9x &rarr; 8.7x &rarr; 5.8x),
  sugiriendo que ALDC hace que el agente edite relativamente mas y explore menos.
</div>

<h2>7. Key Findings / Hallazgos Clave</h2>

<div class="finding critical">
  <h3>7.1 ALDC no mejora la tasa de bug-fix</h3>
  <p>Ningun escenario ALDC supera consistentemente al baseline. En BCApps-5633 (Hard), la resolucion
  viene del modelo (opus) o la persistencia extrema (Copilot, 73 turns), no de las instrucciones ALDC.</p>
</div>

<div class="finding warning">
  <h3>7.2 El conductor es demasiado caro para bug-fix</h3>
  <p>2.8-4.3x overhead de tokens sin mejora en resolucion. Genera soluciones sobre-ingenierizadas:
  modificaciones GraphQL + campos en tablas para un fix de ~9 lineas.</p>
</div>

<div class="finding warning">
  <h3>7.3 El developer es un trade-off ambiguo</h3>
  <p>Copilot+developer resuelve BCApps-5633 (Hard) donde baseline falla — pero falla en BCApps-4822 (Medium)
  donde baseline pasa. Claude+developer: mismos resultados que baseline, 3x tokens.</p>
</div>

<div class="finding">
  <h3>7.4 El modelo importa mas que el framework</h3>
  <p>Opus baseline resuelve BCApps-5633 (1/2 runs) donde <strong>ninguna</strong> configuracion Sonnet lo logra.
  Un upgrade de modelo entrega lo que 300KB de instrucciones no pueden.</p>
</div>

<div class="finding positive">
  <h3>7.5 ALDC esta diseñado para otro caso de uso</h3>
  <p>Bug-fix de ~10 lineas es el <strong>peor caso</strong> para ALDC: maximo overhead, minimo beneficio.
  ALDC esta diseñado para desarrollo guiado por spec con HITL, TDD completo, y features medianas/grandes.
  Evaluarlo en bug-fix sin HITL es como evaluar un piloto de F1 en una calle residencial.</p>
</div>

<h2>8. Recommendations</h2>
<ol>
  <li><strong>ALDC pruned:</strong> Cargar solo 3-4 skills relevantes al tipo de tarea (no las 11 completas). Reducir contexto de ~300KB a ~50KB.</li>
  <li><strong>Baseline context-aware:</strong> Añadir escenario intermedio (solo CLAUDE.md + rules, sin skills/agents) para aislar efecto de instrucciones base.</li>
  <li><strong>Ablation study:</strong> Baseline &rarr; +CLAUDE.md &rarr; +rules &rarr; +skills &rarr; full ALDC.</li>
  <li><strong>Test-generation:</strong> Evaluar conductor en su terreno natural (TDD RED&rarr;GREEN&rarr;REFACTOR).</li>
  <li><strong>Feature-development:</strong> Nuevas tareas donde la orquestacion multi-agente justifique su overhead.</li>
</ol>

<h2>9. Limitations</h2>
<table class="data-table">
  <tr><th>Limitation</th><th>Impact</th></tr>
  <tr><td>n=3 instances</td><td>No statistical significance possible</td></tr>
  <tr><td>Mostly single-run</td><td>No variance estimation</td></tr>
  <tr><td>Sparse matrix</td><td>Not all combinations tested</td></tr>
  <tr><td>Bug-fix only</td><td>Conductor designed for TDD/test-gen</td></tr>
  <tr><td>Bench mode</td><td>No HITL gates — not full ALDC</td></tr>
  <tr><td>Blindness problem</td><td>Cannot verify if model processes instructions</td></tr>
</table>

<script>
  Plotly.newPlot('heatmap', {heatmap.to_json()}.data, {heatmap.to_json()}.layout);
  Plotly.newPlot('tokens', {tokens_chart.to_json()}.data, {tokens_chart.to_json()}.layout);
  Plotly.newPlot('efficiency', {efficiency_chart.to_json()}.data, {efficiency_chart.to_json()}.layout);
</script>

<footer style="margin-top:40px; padding-top:15px; border-top:1px solid #bdc3c7; color:#7f8c8d; font-size:12px;">
  Generated from BC-Bench evaluation data. See <code>notebooks/bug-fix/aldc-comparison-full.ipynb</code> for interactive analysis.
</footer>
</body>
</html>"""

    OUTPUT_HTML.write_text(html, encoding="utf-8")
    print(f"Report written to {OUTPUT_HTML} ({OUTPUT_HTML.stat().st_size / 1024:.0f} KB)")


if __name__ == "__main__":
    generate_report()

#!/usr/bin/env python3
"""Brush Quest Dashboard — zero-dependency local dashboard.

Parses STATUS.md, STRATEGY.md, and git log to render a live project overview.
Run: python3 dashboard/server.py
Open: http://localhost:8080
"""

import http.server
import json
import os
import re
import subprocess
from datetime import datetime
from pathlib import Path

PORT = 8080
PROJECT_ROOT = Path(__file__).resolve().parent.parent
CYCLE_HISTORY_PATH = Path.home() / "Projects" / "dev-cycle" / "projects" / "brush-quest" / "cycle-history.md"

BENCHMARK_ROTATION = {
    1: "Pokemon Smile",
    2: "Brusheez",
    3: "Disney Magic Timer",
    4: "Chomper Chums",
    5: "Brush DJ",
    0: "Habitica (Kids)",
}

# Workstream → category mapping. Unknown workstreams default to "Product".
WORKSTREAM_CATEGORIES = {
    "APP": "Product",
    "LANDING PAGE": "Product",
    "PRICING": "Product",
    "MERCH": "Product",
    "DEV CYCLE": "Ops",
    "STRATEGY": "Ops",
    "LLC": "Business",
    "ACCOUNTING": "Business",
}

CATEGORY_ORDER = ["Product", "Business", "Ops"]
CATEGORY_COLORS = {
    "Product": "#b388ff",
    "Business": "#00e676",
    "Ops": "#00e5ff",
}


def read_file(name):
    path = PROJECT_ROOT / name
    if path.exists():
        return path.read_text()
    return ""


def parse_status():
    """Extract workstream cards and blockers from STATUS.md."""
    text = read_file("STATUS.md")
    if not text:
        return [], [], "", ""

    # Extract top-level info
    priority_match = re.search(r"\*\*Current #1 Priority\*\*:\s*(.+)", text)
    phase_match = re.search(r"\*\*Phase\*\*:\s*(.+)", text)
    priority = priority_match.group(1).strip() if priority_match else "Unknown"
    phase = phase_match.group(1).strip() if phase_match else "Unknown"

    # Extract workstreams
    workstreams = []
    ws_pattern = re.compile(
        r"### (\w[\w\s]*)\n(.*?)(?=\n### |\n---|\Z)", re.DOTALL
    )
    for match in ws_pattern.finditer(text):
        name = match.group(1).strip()
        body = match.group(2).strip()
        fields = {}
        for line in body.split("\n"):
            m = re.match(r"-\s+\*\*(.+?)\*\*:\s*(.+)", line)
            if m:
                fields[m.group(1).strip()] = m.group(2).strip()
        if fields:
            workstreams.append({"name": name, "fields": fields})

    # Extract blockers table
    blockers = []
    in_table = False
    for line in text.split("\n"):
        if line.startswith("| Blocker"):
            in_table = True
            continue
        if in_table and line.startswith("|---"):
            continue
        if in_table and line.startswith("|"):
            cols = [c.strip() for c in line.split("|")[1:-1]]
            if len(cols) >= 5:
                blockers.append(
                    {
                        "blocker": cols[0],
                        "owner": cols[1],
                        "since": cols[2],
                        "impact": cols[3],
                        "status": cols[4],
                    }
                )
        elif in_table:
            in_table = False

    return workstreams, blockers, priority, phase


def parse_strategy():
    """Extract active decisions and current phase from STRATEGY.md."""
    text = read_file("STRATEGY.md")
    if not text:
        return []

    decisions = []
    dec_pattern = re.compile(
        r"### (D-\d+:.+?)\n(.*?)(?=\n### |\n---|\Z)", re.DOTALL
    )
    for match in dec_pattern.finditer(text):
        title = match.group(1).strip()
        body = match.group(2).strip()
        fields = {}
        for line in body.split("\n"):
            m = re.match(r"\*\*(.+?)\*\*:\s*(.+)", line)
            if m:
                fields[m.group(1)] = m.group(2)
        decisions.append({"title": title, "fields": fields})

    return decisions


def parse_cycle_history():
    """Extract dev cycle data from cycle-history.md."""
    if not CYCLE_HISTORY_PATH.exists():
        return {"cycles": [], "deferred": [], "latest": None}

    text = CYCLE_HISTORY_PATH.read_text()

    # Split into cycle entries
    cycle_pattern = re.compile(
        r"## Cycle (\d+) — (\d{4}-\d{2}-\d{2})\n(.*?)(?=\n## Cycle |\Z)",
        re.DOTALL,
    )

    cycles = []
    all_deferred = []

    for match in cycle_pattern.finditer(text):
        num = int(match.group(1))
        date = match.group(2)
        body = match.group(3)

        # Extract mode
        mode_match = re.search(r"\*\*Mode:\*\*\s*(.+)", body)
        mode = mode_match.group(1).strip() if mode_match else "unknown"

        # Extract benchmark
        bench_match = re.search(r"\*\*Benchmark app:\*\*\s*(.+)", body)
        benchmark = bench_match.group(1).strip() if bench_match else ""

        # Extract git range
        git_match = re.search(r"\*\*Git range:\*\*\s*`(.+?)`", body)
        git_range = git_match.group(1).strip() if git_match else ""

        # Count findings by status
        approved = len(re.findall(r"Approved", body))
        deferred = len(re.findall(r"Deferred", body))

        # Extract test count
        test_match = re.search(r"flutter test.*?:\s*(\d+)\s*tests?\s*passed", body)
        test_count = int(test_match.group(1)) if test_match else None

        # Extract APK size
        apk_match = re.search(r"APK size:\s*([\d.]+)\s*MB", body)
        apk_size = float(apk_match.group(1)) if apk_match else None

        # Extract commit hash
        commit_match = re.search(r"Commit:\s*`(\w+)`", body)
        commit = commit_match.group(1) if commit_match else ""

        # Extract benchmark insight
        insight_match = re.search(
            r"_One thing .+? does better.*?:_\n-\s*(.+?)(?:\n\n|\n###|\Z)",
            body,
            re.DOTALL,
        )
        insight = insight_match.group(1).strip() if insight_match else ""

        # Extract deferred items
        deferred_section = re.search(
            r"### Deferred\n(.*?)(?:\n### |\Z)", body, re.DOTALL
        )
        deferred_items = []
        if deferred_section:
            for line in deferred_section.group(1).strip().split("\n"):
                line = line.strip()
                if line.startswith("- ") and not line.startswith("_("):
                    deferred_items.append(line[2:])

        # Extract learnings — "What should next cycle watch for?"
        watch_match = re.search(
            r"\*\*What should next cycle watch for\?\*\*\s*(.+?)(?:\n\n|\n###|\Z)",
            body,
            re.DOTALL,
        )
        watch_for = watch_match.group(1).strip() if watch_match else ""

        cycle = {
            "num": num,
            "date": date,
            "mode": mode,
            "benchmark": benchmark,
            "git_range": git_range,
            "approved": approved,
            "deferred": deferred,
            "test_count": test_count,
            "apk_size": apk_size,
            "commit": commit,
            "insight": insight,
            "deferred_items": deferred_items,
            "watch_for": watch_for,
        }
        cycles.append(cycle)
        all_deferred = deferred_items  # Latest cycle's deferred items

    cycles.sort(key=lambda c: c["num"])
    latest = cycles[-1] if cycles else None
    next_num = (latest["num"] + 1) if latest else 1
    next_benchmark = BENCHMARK_ROTATION.get(next_num % 6, "Unknown")

    return {
        "cycles": cycles,
        "deferred": all_deferred,
        "latest": latest,
        "next_benchmark": next_benchmark,
    }


def get_git_log(count=20):
    """Get recent git log entries."""
    try:
        result = subprocess.run(
            ["git", "log", f"--oneline", f"-{count}", "--no-color"],
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT,
            timeout=5,
        )
        lines = result.stdout.strip().split("\n") if result.stdout.strip() else []
        entries = []
        for line in lines:
            parts = line.split(" ", 1)
            if len(parts) == 2:
                entries.append({"hash": parts[0], "message": parts[1]})
        return entries
    except Exception:
        return []


def get_git_stats():
    """Get basic git stats."""
    stats = {}
    try:
        result = subprocess.run(
            ["git", "rev-list", "--count", "HEAD"],
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT,
            timeout=5,
        )
        stats["total_commits"] = result.stdout.strip()
    except Exception:
        stats["total_commits"] = "?"

    try:
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True,
            text=True,
            cwd=PROJECT_ROOT,
            timeout=5,
        )
        stats["branch"] = result.stdout.strip()
    except Exception:
        stats["branch"] = "?"

    return stats


def status_color(status_text):
    """Map status keywords to colors."""
    s = status_text.lower()
    if any(w in s for w in ["done", "live", "complete", "shipped", "active"]):
        return "#00e676"
    if any(w in s for w in ["blocked", "rejected", "failed"]):
        return "#ff5252"
    if any(w in s for w in ["pending", "todo", "in development", "in progress"]):
        return "#ffd740"
    return "#b0bec5"


def render_html():
    """Build the full dashboard HTML."""
    workstreams, blockers, priority, phase = parse_status()
    decisions = parse_strategy()
    cycle_data = parse_cycle_history()
    git_log = get_git_log()
    git_stats = get_git_stats()
    now = datetime.now().strftime("%Y-%m-%d %H:%M")

    # Build workstream cards grouped by category
    def build_ws_card(ws):
        f = ws["fields"]
        status = f.get("Status", "Unknown")
        color = status_color(status)
        blocked = f.get("Blocked on", "Nothing")
        next_up = f.get("Next up", "—")
        last_commit = f.get("Last commit", "—")
        what = f.get("What happened", "—")
        ceo = f.get("Needs CEO decision", "None")

        blocked_html = ""
        if blocked.lower() not in ("nothing", "none", "—"):
            blocked_html = f'<div class="blocked">BLOCKED: {blocked}</div>'

        ceo_html = ""
        if ceo.lower() not in ("none", "n/a", "—"):
            ceo_html = f'<div class="ceo-need">CEO: {ceo}</div>'

        return f"""
        <div class="card">
            <div class="card-header">
                <span class="ws-name">{ws['name']}</span>
                <span class="status-dot" style="background:{color}"></span>
            </div>
            <div class="status-line">{status}</div>
            {blocked_html}
            <div class="field"><span class="label">Last commit:</span> <code>{last_commit}</code></div>
            <div class="field"><span class="label">What happened:</span> {what}</div>
            <div class="field"><span class="label">Next up:</span> {next_up}</div>
            {ceo_html}
        </div>"""

    # Group workstreams by category
    grouped = {}
    for ws in workstreams:
        cat = WORKSTREAM_CATEGORIES.get(ws["name"].upper(), "Product")
        grouped.setdefault(cat, []).append(ws)

    ws_sections = ""
    for cat in CATEGORY_ORDER:
        items = grouped.get(cat, [])
        if not items:
            continue
        cat_color = CATEGORY_COLORS.get(cat, "#b0bec5")
        cards = "".join(build_ws_card(ws) for ws in items)
        ws_sections += f"""
    <div class="category-header">
        <span class="category-dot" style="background:{cat_color}"></span>
        <span class="category-name" style="color:{cat_color}">{cat.upper()}</span>
        <span class="category-line" style="background:{cat_color}22"></span>
    </div>
    <div class="grid">
        {cards}
    </div>"""

    # Build decisions
    dec_html = ""
    for d in decisions:
        f = d["fields"]
        dec_status = f.get("Status", "Unknown")
        color = status_color(dec_status)
        dec_html += f"""
        <div class="decision">
            <span class="dec-title">{d['title']}</span>
            <span class="dec-status" style="color:{color}">{dec_status}</span>
            <div class="dec-detail">{f.get('Decision', f.get('Context', '—'))}</div>
        </div>"""

    # Build blockers
    blocker_rows = ""
    for b in blockers:
        color = status_color(b["status"])
        blocker_rows += f"""
        <tr>
            <td>{b['blocker']}</td>
            <td>{b['owner']}</td>
            <td>{b['since']}</td>
            <td>{b['impact']}</td>
            <td style="color:{color}">{b['status']}</td>
        </tr>"""

    # Build dev cycle section
    cycle_html = ""
    if cycle_data["latest"]:
        latest = cycle_data["latest"]
        cycles = cycle_data["cycles"]

        # Stats row
        cycle_html += f"""
        <div class="cycle-stats">
            <div class="stat">
                <div class="num">{latest['num']}</div>
                <div class="lbl">Last Cycle</div>
            </div>
            <div class="stat">
                <div class="num">{latest['approved']}</div>
                <div class="lbl">Approved</div>
            </div>
            <div class="stat">
                <div class="num">{latest['deferred']}</div>
                <div class="lbl">Deferred</div>
            </div>
            <div class="stat">
                <div class="num">{latest['test_count'] or '?'}</div>
                <div class="lbl">Tests</div>
            </div>
            <div class="stat">
                <div class="num">{latest['apk_size'] or '?'}<span style="font-size:12px;color:#666"> MB</span></div>
                <div class="lbl">APK</div>
            </div>
        </div>"""

        # Latest cycle summary
        cycle_html += f"""
        <div class="cycle-latest">
            <div class="field"><span class="label">Date:</span> {latest['date']}</div>
            <div class="field"><span class="label">Mode:</span> {latest['mode']}</div>
            <div class="field"><span class="label">Benchmark:</span> {latest['benchmark']}</div>
            <div class="field"><span class="label">Commit:</span> <code>{latest['commit']}</code></div>
        </div>"""

        # Metrics trend (if >1 cycle)
        if len(cycles) > 1:
            trend_html = '<div class="cycle-trend"><span class="label">Trend:</span> '
            for c in cycles:
                test_str = str(c["test_count"]) if c["test_count"] else "?"
                apk_str = f"{c['apk_size']}MB" if c["apk_size"] else "?"
                trend_html += f'<span class="trend-point">C{c["num"]}: {test_str} tests, {apk_str}</span>'
                if c != cycles[-1]:
                    trend_html += ' <span style="color:#333"> → </span> '
            trend_html += "</div>"
            cycle_html += trend_html

        # Benchmark insight
        if latest["insight"]:
            short_insight = latest["insight"][:200]
            cycle_html += f"""
        <div class="cycle-insight">
            <span class="label">Benchmark insight ({latest['benchmark']}):</span> {short_insight}
        </div>"""

        # Deferred backlog
        if cycle_data["deferred"]:
            backlog_items = ""
            for item in cycle_data["deferred"]:
                backlog_items += f'<div class="deferred-item">{item}</div>'
            cycle_html += f"""
        <div class="cycle-deferred">
            <div class="deferred-title">Deferred Backlog ({len(cycle_data['deferred'])} items)</div>
            {backlog_items}
        </div>"""

        # Next cycle info
        cycle_html += f"""
        <div class="cycle-next">
            Next: <strong>Cycle {latest['num'] + 1}</strong> — Benchmark: <strong>{cycle_data['next_benchmark']}</strong>
        </div>"""
    else:
        cycle_html = '<div style="color:#666;font-size:13px">No cycles yet. Run <code>/cycle</code> to start.</div>'

    # Build git log
    git_html = ""
    for entry in git_log[:15]:
        git_html += f"""
        <div class="git-entry">
            <code class="hash">{entry['hash']}</code>
            <span>{entry['message']}</span>
        </div>"""

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Brush Quest Dashboard</title>
<link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png">
<link rel="icon" type="image/png" sizes="192x192" href="/favicon.png">
<meta http-equiv="refresh" content="30">
<style>
    * {{ margin: 0; padding: 0; box-sizing: border-box; }}
    body {{
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
        background: #0a0a1a;
        color: #e0e0e0;
        min-height: 100vh;
        padding: 24px;
    }}
    .header {{
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 24px;
        padding-bottom: 16px;
        border-bottom: 1px solid #1a1a3a;
    }}
    .header h1 {{
        font-size: 28px;
        background: linear-gradient(135deg, #b388ff, #00e5ff);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
    }}
    .header .meta {{
        text-align: right;
        font-size: 13px;
        color: #666;
    }}
    .priority-banner {{
        background: linear-gradient(135deg, #1a0a2e, #0a1a2e);
        border: 1px solid #b388ff44;
        border-radius: 12px;
        padding: 20px 24px;
        margin-bottom: 24px;
        text-align: center;
    }}
    .priority-banner .label {{
        font-size: 11px;
        text-transform: uppercase;
        letter-spacing: 2px;
        color: #b388ff;
        margin-bottom: 8px;
    }}
    .priority-banner .text {{
        font-size: 20px;
        font-weight: 600;
        color: #fff;
    }}
    .priority-banner .phase {{
        font-size: 13px;
        color: #00e5ff;
        margin-top: 8px;
    }}
    .section-title {{
        font-size: 14px;
        text-transform: uppercase;
        letter-spacing: 1.5px;
        color: #b388ff;
        margin: 24px 0 12px;
    }}
    .grid {{
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
        gap: 16px;
        margin-bottom: 24px;
    }}
    .card {{
        background: #111128;
        border: 1px solid #1a1a3a;
        border-radius: 12px;
        padding: 20px;
    }}
    .card-header {{
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 12px;
    }}
    .ws-name {{
        font-size: 16px;
        font-weight: 700;
        color: #fff;
    }}
    .status-dot {{
        width: 10px;
        height: 10px;
        border-radius: 50%;
        display: inline-block;
    }}
    .status-line {{
        font-size: 14px;
        color: #b0bec5;
        margin-bottom: 12px;
    }}
    .blocked {{
        background: #ff525220;
        border: 1px solid #ff525244;
        border-radius: 6px;
        padding: 8px 12px;
        font-size: 13px;
        color: #ff8a80;
        margin-bottom: 12px;
    }}
    .ceo-need {{
        background: #ffd74020;
        border: 1px solid #ffd74044;
        border-radius: 6px;
        padding: 8px 12px;
        font-size: 13px;
        color: #ffd740;
        margin-top: 12px;
    }}
    .field {{
        font-size: 13px;
        color: #999;
        margin-bottom: 6px;
        line-height: 1.4;
    }}
    .field .label {{ color: #b388ff; }}
    .field code {{
        background: #1a1a3a;
        padding: 2px 6px;
        border-radius: 4px;
        font-size: 12px;
    }}
    .decisions {{
        background: #111128;
        border: 1px solid #1a1a3a;
        border-radius: 12px;
        padding: 20px;
        margin-bottom: 24px;
    }}
    .decision {{
        padding: 12px 0;
        border-bottom: 1px solid #1a1a3a;
    }}
    .decision:last-child {{ border-bottom: none; }}
    .dec-title {{
        font-weight: 600;
        color: #fff;
        font-size: 14px;
    }}
    .dec-status {{
        font-size: 12px;
        font-weight: 600;
        float: right;
    }}
    .dec-detail {{
        font-size: 13px;
        color: #999;
        margin-top: 4px;
    }}
    .two-col {{
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 16px;
    }}
    @media (max-width: 768px) {{
        .two-col {{ grid-template-columns: 1fr; }}
    }}
    .blockers-table {{
        width: 100%;
        border-collapse: collapse;
        font-size: 13px;
    }}
    .blockers-table th {{
        text-align: left;
        padding: 8px 12px;
        color: #b388ff;
        border-bottom: 1px solid #1a1a3a;
        font-size: 11px;
        text-transform: uppercase;
        letter-spacing: 1px;
    }}
    .blockers-table td {{
        padding: 8px 12px;
        border-bottom: 1px solid #0a0a1a;
        color: #b0bec5;
    }}
    .panel {{
        background: #111128;
        border: 1px solid #1a1a3a;
        border-radius: 12px;
        padding: 20px;
    }}
    .git-entry {{
        padding: 6px 0;
        font-size: 13px;
        border-bottom: 1px solid #0a0a1a;
    }}
    .git-entry:last-child {{ border-bottom: none; }}
    .git-entry .hash {{
        background: #1a1a3a;
        padding: 2px 6px;
        border-radius: 4px;
        font-size: 12px;
        color: #00e5ff;
        margin-right: 8px;
    }}
    .stats-row {{
        display: flex;
        gap: 24px;
        margin-bottom: 16px;
    }}
    .stat {{
        text-align: center;
    }}
    .stat .num {{
        font-size: 24px;
        font-weight: 700;
        color: #00e5ff;
    }}
    .stat .lbl {{
        font-size: 11px;
        text-transform: uppercase;
        letter-spacing: 1px;
        color: #666;
    }}
    /* Category headers */
    .category-header {{
        display: flex;
        align-items: center;
        gap: 8px;
        margin: 16px 0 8px;
    }}
    .category-header:first-child {{
        margin-top: 0;
    }}
    .category-dot {{
        width: 8px;
        height: 8px;
        border-radius: 50%;
        flex-shrink: 0;
    }}
    .category-name {{
        font-size: 11px;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 2px;
        white-space: nowrap;
    }}
    .category-line {{
        flex: 1;
        height: 1px;
    }}
    /* Dev Cycle section */
    .cycle-stats {{
        display: flex;
        gap: 32px;
        margin-bottom: 16px;
        padding-bottom: 16px;
        border-bottom: 1px solid #1a1a3a;
    }}
    .cycle-latest {{
        margin-bottom: 12px;
    }}
    .cycle-trend {{
        font-size: 13px;
        color: #666;
        margin-bottom: 12px;
    }}
    .cycle-trend .trend-point {{
        color: #b0bec5;
    }}
    .cycle-insight {{
        font-size: 13px;
        color: #999;
        background: #0a1a2e;
        border: 1px solid #00e5ff22;
        border-radius: 8px;
        padding: 12px;
        margin-bottom: 12px;
        line-height: 1.5;
    }}
    .cycle-deferred {{
        margin-bottom: 12px;
    }}
    .deferred-title {{
        font-size: 12px;
        text-transform: uppercase;
        letter-spacing: 1px;
        color: #ffd740;
        margin-bottom: 8px;
    }}
    .deferred-item {{
        font-size: 13px;
        color: #b0bec5;
        padding: 6px 12px;
        background: #ffd74010;
        border-left: 3px solid #ffd74044;
        margin-bottom: 4px;
        border-radius: 0 6px 6px 0;
    }}
    .cycle-next {{
        font-size: 13px;
        color: #666;
        padding-top: 12px;
        border-top: 1px solid #1a1a3a;
    }}
    .cycle-next strong {{
        color: #b388ff;
    }}
</style>
</head>
<body>

<div class="header">
    <h1>Brush Quest</h1>
    <div class="meta">
        <div>Branch: <code>{git_stats.get('branch', '?')}</code></div>
        <div>{git_stats.get('total_commits', '?')} commits</div>
        <div>Updated: {now}</div>
    </div>
</div>

<div class="priority-banner">
    <div class="label">Current #1 Priority</div>
    <div class="text">{priority}</div>
    <div class="phase">Phase: {phase}</div>
</div>

<div class="section-title">Workstreams</div>
{ws_sections}

<div class="section-title">Dev Cycle</div>
<div class="panel" style="margin-bottom:24px">
    {cycle_html}
</div>

<div class="section-title">Active Decisions</div>
<div class="decisions">
    {dec_html if dec_html else '<div style="color:#666;font-size:13px">No active decisions</div>'}
</div>

<div class="section-title">Blockers</div>
<div class="panel" style="margin-bottom:24px">
    <table class="blockers-table">
        <tr><th>Blocker</th><th>Owner</th><th>Since</th><th>Impact</th><th>Status</th></tr>
        {blocker_rows if blocker_rows else '<tr><td colspan="5" style="color:#666">No blockers</td></tr>'}
    </table>
</div>

<div class="section-title">Recent Activity</div>
<div class="panel">
    {git_html if git_html else '<div style="color:#666;font-size:13px">No git history</div>'}
</div>

</body>
</html>"""


class DashboardHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            html = render_html()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            self.wfile.write(html.encode())
        elif self.path == "/api/status":
            workstreams, blockers, priority, phase = parse_status()
            data = {
                "priority": priority,
                "phase": phase,
                "workstreams": workstreams,
                "blockers": blockers,
                "decisions": parse_strategy(),
                "cycle": parse_cycle_history(),
                "git_log": get_git_log(),
                "git_stats": get_git_stats(),
            }
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(data, indent=2).encode())
        elif self.path in ("/favicon.png", "/favicon-32.png"):
            favicon_path = PROJECT_ROOT / "docs" / self.path.lstrip("/")
            if favicon_path.exists():
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.send_header("Cache-Control", "public, max-age=86400")
                self.end_headers()
                self.wfile.write(favicon_path.read_bytes())
            else:
                self.send_response(404)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Quieter logging
        pass


def main():
    server = http.server.HTTPServer(("", PORT), DashboardHandler)
    print(f"\n  Brush Quest Dashboard")
    print(f"  http://localhost:{PORT}")
    print(f"  Auto-refreshes every 30s")
    print(f"  Press Ctrl+C to stop\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n  Dashboard stopped.")
        server.server_close()


if __name__ == "__main__":
    main()

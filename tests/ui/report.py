"""Test reports for the UI tests, written by conftest.py at the end of a run.

- summary.md: a Markdown table of every test, for the PR comment and the
  GitHub job summary.
- report.html: the same table with each test's screenshot and, for failures,
  the error and a link to the Playwright trace. Open it from the unzipped
  artifact (or test-results/ locally); screenshots are relative links.
- results.json: the raw results.
"""

import html
import json
import os
from datetime import datetime, timezone
from pathlib import Path

ICONS = {"passed": "✅", "failed": "❌", "error": "💥", "skipped": "⏭️"}
LABELS = {"passed": "Passed", "failed": "Failed", "error": "Error", "skipped": "Skipped"}
MAX_MESSAGE = 1500


def title(r):
    name = r["name"].removeprefix("test_").replace("_", " ")
    name = name[:1].upper() + name[1:]
    if r["params"] is not None:
        name += f" ({r['params'] or 'empty'})"
    return name


def fmt_time(seconds):
    if seconds < 60:
        return f"{seconds:.1f} s"
    m, s = divmod(round(seconds), 60)
    return f"{m}m {s:02d}s"


def counts(results):
    c = {k: 0 for k in LABELS}
    for r in results:
        c[r["outcome"]] += 1
    return c


def headline(results):
    c = counts(results)
    bad = c["failed"] + c["error"]
    parts = [f"{c[k]} {LABELS[k].lower()}" for k in ("failed", "error", "passed", "skipped") if c[k]]
    return ("❌" if bad else "✅"), ", ".join(parts) or "no tests"


def by_file(results):
    files = {}
    for r in results:
        files.setdefault(r["file"], []).append(r)
    return files


def short_message(message):
    message = message.strip()
    return message if len(message) <= MAX_MESSAGE else message[:MAX_MESSAGE] + "\n..."


def markdown(results, elapsed):
    icon, text = headline(results)
    c = counts(results)
    lines = [
        f"## {icon} UI tests: {text}",
        "",
        f"{len(results)} tests in {fmt_time(elapsed)} · ✅ {c['passed']} passed · ❌ {c['failed'] + c['error']} failed"
        f" · ⏭️ {c['skipped']} skipped",
        "",
        "| Result | Test | File | Time |",
        "|:-:|---|---|--:|",
    ]
    for file, rows in by_file(results).items():
        for r in rows:
            name = title(r).replace("|", "\\|")
            lines.append(f"| {ICONS[r['outcome']]} | {name} | `{file}` | {fmt_time(r['duration'])} |")
    failures = [r for r in results if r["outcome"] in ("failed", "error")]
    if failures:
        lines += ["", "### Failures", ""]
        for r in failures:
            lines += [
                f"<details><summary><b>{html.escape(title(r))}</b> (<code>{r['file']}</code>)</summary>",
                "",
                "```text",
                short_message(r["message"]),
                "```",
                "</details>",
                "",
            ]
    return "\n".join(lines) + "\n"


CSS = """
:root { --bg:#f7f7f5; --card:#fff; --ink:#1d1d1b; --muted:#6b6b66; --line:#e3e2de;
  --pass:#13795b; --pass-bg:#e3f4ec; --fail:#b42318; --fail-bg:#fde8e7; --skip:#8a6100; --skip-bg:#fdf3d7;
  --accent:#1c5cab; }
@media (prefers-color-scheme: dark) { :root { --bg:#161615; --card:#1f1f1e; --ink:#ecebe7; --muted:#a3a29c;
  --line:#33332f; --pass:#5fd3a5; --pass-bg:#173328; --fail:#ff8a80; --fail-bg:#3a1d1b; --skip:#f2c35b;
  --skip-bg:#3a3018; --accent:#7fb0f0; } }
* { box-sizing:border-box; }
[hidden] { display:none !important; }
body { margin:0; background:var(--bg); color:var(--ink);
  font:14px/1.45 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif; }
main { max-width:1200px; margin:0 auto; padding:24px 16px 48px; }
h1 { font-size:22px; margin:0 0 4px; }
.meta { color:var(--muted); margin-bottom:20px; }
.meta a { color:var(--accent); }
.tiles { display:grid; grid-template-columns:repeat(auto-fit,minmax(140px,1fr)); gap:12px; margin-bottom:20px; }
.tile { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:12px 14px; }
.tile b { display:block; font-size:24px; }
.tile span { color:var(--muted); }
.filters { display:flex; flex-wrap:wrap; gap:8px; margin-bottom:12px; }
.filters button { border:1px solid var(--line); background:var(--card); color:var(--ink); border-radius:999px;
  padding:5px 12px; cursor:pointer; font:inherit; }
.filters button[aria-pressed=true] { border-color:var(--accent); color:var(--accent); font-weight:600; }
.table { background:var(--card); border:1px solid var(--line); border-radius:10px; overflow:hidden; }
table { width:100%; border-collapse:collapse; }
th, td { text-align:left; padding:10px 12px; border-bottom:1px solid var(--line); vertical-align:top; }
th { font-size:12px; text-transform:uppercase; letter-spacing:.04em; color:var(--muted); }
tr.file td { background:var(--bg); font-weight:600; font-family:ui-monospace,Consolas,monospace; font-size:13px; }
td.time { text-align:right; white-space:nowrap; color:var(--muted); }
.pill { display:inline-block; border-radius:999px; padding:2px 10px; font-size:12px; font-weight:600; white-space:nowrap; }
.passed .pill { color:var(--pass); background:var(--pass-bg); }
.failed .pill, .error .pill { color:var(--fail); background:var(--fail-bg); }
.skipped .pill { color:var(--skip); background:var(--skip-bg); }
.shot img { width:280px; max-width:100%; border:1px solid var(--line); border-radius:6px; display:block; }
.shot a { display:block; cursor:zoom-in; }
dialog { border:0; padding:0; background:transparent; max-width:96vw; max-height:96vh; }
dialog::backdrop { background:rgba(0,0,0,.75); }
dialog img { max-width:96vw; max-height:88vh; display:block; border-radius:8px; cursor:zoom-out; }
dialog p { color:#fff; margin:8px 0 0; text-align:center; }
pre { white-space:pre-wrap; word-break:break-word; background:var(--bg); border:1px solid var(--line);
  border-radius:6px; padding:10px; margin:8px 0 0; font-size:12px; max-height:320px; overflow:auto; }
details summary { cursor:pointer; color:var(--fail); }
.links a { color:var(--accent); margin-right:10px; }
@media (max-width:700px) {
  thead { display:none; }
  tr.test { display:grid; grid-template-columns:1fr auto; border-bottom:1px solid var(--line); }
  tr.test td { border:0; padding:8px 12px; }
  tr.test td:nth-child(2) { grid-column:1 / -1; grid-row:2; padding-top:0; }
  tr.test td.shot { grid-column:1 / -1; padding-top:0; }
  tr.file td { display:block; }
  .shot img { width:100%; }
}
"""

JS = """
const box = document.getElementById('lightbox');
document.querySelectorAll('.shot a').forEach(a => a.addEventListener('click', ev => {
  ev.preventDefault();
  box.querySelector('img').src = a.href;
  box.querySelector('img').alt = a.querySelector('img').alt;
  box.querySelector('p').textContent = a.dataset.title;
  box.showModal();
}));
box.addEventListener('click', () => box.close());
document.querySelectorAll('.filters button').forEach(b => b.addEventListener('click', () => {
  document.querySelectorAll('.filters button').forEach(x => x.setAttribute('aria-pressed', x === b));
  const want = b.dataset.filter;
  document.querySelectorAll('tr.test').forEach(tr => {
    tr.hidden = !(want === 'all' || tr.dataset.outcome === want ||
                  (want === 'failed' && tr.dataset.outcome === 'error'));
  });
  document.querySelectorAll('tr.file').forEach(tr => {
    tr.hidden = !document.querySelector(`tr.test[data-file="${tr.dataset.file}"]:not([hidden])`);
  });
}));
"""


def html_report(results, elapsed):
    e = html.escape
    icon, text = headline(results)
    c = counts(results)
    meta = [datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"), f"{len(results)} tests in {fmt_time(elapsed)}"]
    if os.environ.get("GITHUB_RUN_ID"):
        repo_url = f"{os.environ.get('GITHUB_SERVER_URL', 'https://github.com')}/{os.environ.get('GITHUB_REPOSITORY', '')}"
        sha = os.environ.get("GITHUB_SHA", "")[:7]
        meta.append(f'commit <a href="{e(repo_url)}/commit/{e(os.environ.get("GITHUB_SHA", ""))}">{e(sha)}</a>')
        meta.append(f'<a href="{e(repo_url)}/actions/runs/{e(os.environ["GITHUB_RUN_ID"])}">run log</a>')
    tiles = "".join(
        f'<div class="tile"><b>{n}</b><span>{label}</span></div>'
        for n, label in [(len(results), "Tests"), (c["passed"], "Passed"), (c["failed"] + c["error"], "Failed"),
                         (c["skipped"], "Skipped"), (fmt_time(elapsed), "Duration")]
    )
    rows = []
    for file, tests in by_file(results).items():
        rows.append(f'<tr class="file" data-file="{e(file)}"><td colspan="4">{e(file)}</td></tr>')
        for r in tests:
            o = r["outcome"]
            detail = ""
            if r["message"] and o != "passed":
                detail = f"<pre>{e(short_message(r['message']))}</pre>"
            if r.get("details"):
                detail += f"<details><summary>Full traceback</summary><pre>{e(r['details'])}</pre></details>"
            links = ""
            if r.get("trace"):
                links = f'<div class="links"><a href="{e(r["trace"])}">Playwright trace</a></div>'
            shot = (f'<a href="{e(r["screenshot"])}" data-title="{e(title(r))}"><img loading="lazy" src="{e(r["screenshot"])}" '
                    f'alt="Screenshot at the end of: {e(title(r))}"></a>') if r.get("screenshot") else ""
            rows.append(
                f'<tr class="test {o}" data-outcome="{o}" data-file="{e(file)}">'
                f'<td><span class="pill">{ICONS[o]} {LABELS[o]}</span></td>'
                f"<td>{e(title(r))}{detail}{links}</td>"
                f'<td class="time">{fmt_time(r["duration"])}</td>'
                f'<td class="shot">{shot}</td></tr>'
            )
    bad = c["failed"] + c["error"]
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>UI Test Report</title><style>{CSS}</style></head>
<body><main>
<h1>{icon} UI tests: {e(text)}</h1>
<div class="meta">{" · ".join(meta)}</div>
<div class="tiles">{tiles}</div>
<div class="filters" role="group" aria-label="Show">
<button data-filter="all" aria-pressed="true">All ({len(results)})</button>
<button data-filter="passed" aria-pressed="false">Passed ({c["passed"]})</button>
<button data-filter="failed" aria-pressed="false">Failed ({bad})</button>
<button data-filter="skipped" aria-pressed="false">Skipped ({c["skipped"]})</button>
</div>
<div class="table"><table>
<thead><tr><th>Result</th><th>Test</th><th class="time">Time</th><th class="shot">Screenshot</th></tr></thead>
<tbody>{"".join(rows)}</tbody></table></div>
</main>
<dialog id="lightbox" aria-label="Screenshot"><img src="" alt=""><p></p></dialog>
<script>{JS}</script></body></html>
"""


def write_reports(results, out_dir: Path, elapsed: float):
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "results.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    (out_dir / "summary.md").write_text(markdown(results, elapsed), encoding="utf-8")
    (out_dir / "report.html").write_text(html_report(results, elapsed), encoding="utf-8")

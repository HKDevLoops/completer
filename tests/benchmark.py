#!/usr/bin/env python3
"""Measure shell startup, lazy-load source cost, and first invocation cost.

Runs each shell in a fresh process with an isolated HOME/XDG_CONFIG_HOME so no
real config file is modified. Results are emitted as JSON and a styled Excel
workbook with native charts (openpyxl; no external report engine required).
"""
import json
import os
import statistics
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPEATS = 5
OUT_DIR = ROOT / "reports"
OUT_DIR.mkdir(exist_ok=True)


def make_fake_program(bin_dir: Path):
    sh = bin_dir / "fakeprog"
    sh.write_text("#!/bin/sh\nprintf '%s\\n' __fake_completion_value__\n", encoding="utf-8")
    sh.chmod(0o755)
    cmd = bin_dir / "fakeprog.cmd"
    cmd.write_text("@echo __fake_completion_value__\r\n", encoding="utf-8")


def time_cmd(cmd, env, cwd) -> float:
    import time
    start = time.perf_counter()
    subprocess.run(cmd, env=env, cwd=cwd, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL, check=False)
    return (time.perf_counter() - start) * 1000.0


def main():
    tmp = Path(tempfile.mkdtemp(prefix="completer-bench-"))
    env = dict(os.environ)
    env["COMPLETER_ROOT"] = (tmp / "root").as_posix()
    env["XDG_CONFIG_HOME"] = (tmp / "xdg").as_posix()
    env["HOME"] = tmp.as_posix()
    (tmp / "root").mkdir(parents=True, exist_ok=True)
    (tmp / "xdg").mkdir(parents=True, exist_ok=True)
    bin_dir = tmp / "bin"
    bin_dir.mkdir(exist_ok=True)
    make_fake_program(bin_dir)
    env["PATH"] = bin_dir.as_posix() + os.pathsep + env.get("PATH", "")

    src = {s: (ROOT / f"completer.{s}").as_posix()
           for s in ("ps1", "bash", "sh", "nu", "xsh")}
    # xonsh needs execx to load the file into the live context.
    xsh_load = ("execx(open('%s',encoding='utf-8').read(),'exec',__xonsh__.ctx,"
                "filename='completer.xsh')" % src["xsh"])

    suites = {
        "PowerShell": {
            "baseline": ["pwsh", "-NoLogo", "-NoProfile", "-Command", "exit"],
            "source":   ["pwsh", "-NoLogo", "-NoProfile", "-Command", f". '{src['ps1']}'; exit"],
            "list":     ["pwsh", "-NoLogo", "-NoProfile", "-Command", f". '{src['ps1']}'; completer list | Out-Null; exit"],
            "generate": ["pwsh", "-NoLogo", "-NoProfile", "-Command", f". '{src['ps1']}'; completer pwsh fakeprog -NoLink | Out-Null; exit"],
        },
        "Bash": {
            "baseline": ["bash", "-c", ":"],
            "source":   ["bash", "-c", f". '{src['bash']}'"],
            "list":     ["bash", "-c", f". '{src['bash']}'; completer list >/dev/null"],
            "generate": ["bash", "-c", f". '{src['bash']}'; completer bash fakeprog >/dev/null"],
        },
        "POSIX sh": {
            "baseline": ["sh", "-c", ":"],
            "source":   ["sh", "-c", f". '{src['sh']}'"],
            "list":     ["sh", "-c", f". '{src['sh']}'; completer list >/dev/null"],
            "generate": ["sh", "-c", f". '{src['sh']}'; completer sh fakeprog >/dev/null"],
        },
        "Nushell": {
            "baseline": ["nu", "--no-config-file", "-c", "1"],
            "source":   ["nu", "--no-config-file", "-c", f"source '{src['nu']}'"],
            "list":     ["nu", "--no-config-file", "-c", f"source '{src['nu']}'; completer list | ignore"],
            "generate": ["nu", "--no-config-file", "-c", f"source '{src['nu']}'; completer nu fakeprog | ignore"],
        },
        "xonsh": {
            "baseline": ["xonsh", "--no-rc", "-c", "pass"],
            "source":   ["xonsh", "--no-rc", "-c", xsh_load],
            "list":     ["xonsh", "--no-rc", "-c", xsh_load + "; completer('list')"],
            "generate": ["xonsh", "--no-rc", "-c", xsh_load + "; completer('xonsh','fakeprog')"],
        },
    }

    results = {}
    for shell, phases in suites.items():
        results[shell] = {}
        for phase, cmd in phases.items():
            time_cmd(cmd, env, ROOT)  # warm-up
            samples = [time_cmd(cmd, env, ROOT) for _ in range(REPEATS)]
            results[shell][phase] = {
                "median_ms": round(statistics.median(samples), 2),
                "min_ms": round(min(samples), 2),
                "samples_ms": [round(s, 2) for s in samples],
            }
            print(f"{shell:12} {phase:9} median={results[shell][phase]['median_ms']:8.2f} ms")

    payload = {"repeats": REPEATS, "isolated": True, "results": results}
    (OUT_DIR / "benchmark.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")

    try:
        from openpyxl import Workbook
        from openpyxl.chart import BarChart, Reference
        from openpyxl.styles import Alignment, Font, PatternFill
        from openpyxl.utils import get_column_letter
    except ImportError:
        print("openpyxl not available; JSON results still written")
        return

    wb = Workbook()
    ws = wb.active
    ws.title = "Performance"
    ws.append(["Shell", "Baseline (ms)", "Source only (ms)", "Lazy delta (ms)",
               "First call: list (ms)", "First call: generate (ms)"])
    for c in ws[1]:
        c.font = Font(bold=True, color="FFFFFF")
        c.fill = PatternFill("solid", fgColor="1F4E78")
        c.alignment = Alignment(horizontal="center")
    for shell, phases in results.items():
        base = phases["baseline"]["median_ms"]
        src_ms = phases["source"]["median_ms"]
        ws.append([shell, base, src_ms, round(src_ms - base, 2),
                   phases["list"]["median_ms"], phases["generate"]["median_ms"]])
    for col in range(1, 7):
        ws.column_dimensions[get_column_letter(col)].width = 20
    ws.freeze_panes = "A2"

    chart = BarChart()
    chart.type = "col"
    chart.title = "Completer cost by shell (median ms)"
    chart.y_axis.title = "milliseconds"
    chart.x_axis.title = "Shell"
    chart.add_data(Reference(ws, min_col=2, max_col=2, min_row=1, max_row=1 + len(results)), titles_from_data=True)
    chart.add_data(Reference(ws, min_col=3, max_col=3, min_row=1, max_row=1 + len(results)), titles_from_data=True)
    chart.add_data(Reference(ws, min_col=5, max_col=6, min_row=1, max_row=1 + len(results)), titles_from_data=True)
    chart.set_categories(Reference(ws, min_col=1, min_row=2, max_row=1 + len(results)))
    chart.height, chart.width = 9, 20
    ws.add_chart(chart, "H2")

    raw = wb.create_sheet("Raw samples")
    raw.append(["Shell", "Phase", "Sample #", "Milliseconds"])
    for c in raw[1]:
        c.font = Font(bold=True)
    for shell, phases in results.items():
        for phase, data in phases.items():
            for i, sample in enumerate(data["samples_ms"], 1):
                raw.append([shell, phase, i, sample])
    for col, width in zip("ABCD", (14, 12, 10, 14)):
        raw.column_dimensions[col].width = width
    raw.freeze_panes = "A2"

    notes = wb.create_sheet("Methodology")
    notes.append(["Completer launch-time & lazy-loading report"])
    notes["A1"].font = Font(bold=True, size=14)
    lines = [
        "",
        f"Repeats per phase: {REPEATS} (median reported; one warm-up discarded).",
        "Every phase runs in a FRESH process with HOME/XDG_CONFIG_HOME/COMPLETER_ROOT",
        "pointed at a throwaway directory, so no real shell config is read or written.",
        "",
        "Phases:",
        "  baseline  = shell starts and exits; no completer file loaded.",
        "  source    = shell starts and sources completer.<ext> with NO invocation.",
        "  lazy delta = source minus baseline; ~0 proves zero startup cost.",
        "  list      = first invocation: `completer list`.",
        "  generate  = first invocation: one completion generation.",
        "",
        "Sheets: 'Performance' (summary + chart), 'Raw samples' (all timings).",
        "Generated by tests/benchmark.py (openpyxl native charts, no install).",
    ]
    for line in lines:
        notes.append([line])
    notes.column_dimensions["A"].width = 100

    xlsx = OUT_DIR / "completer-performance.xlsx"
    wb.save(xlsx)
    print(f"WROTE {xlsx}")


if __name__ == "__main__":
    main()

# Completer performance reports

Generated 2026-11-25 from `tests/benchmark.py` (five available shells: PowerShell,
Bash, POSIX sh, Nushell, xonsh). Each phase runs in a **fresh process** with
`HOME`, `XDG_CONFIG_HOME` and `COMPLETER_ROOT` pointed at a throwaway directory,
so no real shell config is read or written. Five timings per phase; median shown,
one warm-up discarded.

| File | What it is |
|---|---|
| `benchmark.json` | Raw timings (median, min, all samples) per shell/phase |
| `completer-performance.xlsx` | Excel workbook — summary table, native bar chart, raw samples, methodology |
| `completer-performance.deckcraft` | ArtCraft DeckCraft source document |
| `completer-performance.pptx` | ArtCraft DeckCraft export — slides with the summary table and chart |
| `completer-performance.pdf` | ArtCraft DeckCraft PDF export of the same slides |

## Generation

```sh
python tests/benchmark.py          # -> benchmark.json + .xlsx (openpyxl)
```

The `.deckcraft` / `.pptx` / `.pdf` were produced by driving the **ArtCraft
DeckCraft MCP server** (`deckcraft-cli.exe mcp`) with `new_presentation`,
`add_slide`, `insert_table`, `insert_chart`, `save_presentation` and `export`.
DeckCraft is the installed ArtCraft app that exposes native table/chart MCP
tools; ArtCraft's spreadsheet app (GridCraft) is not installed on this host.

## What the numbers show

`source only` minus `baseline` is the lazy-load cost — sourcing the completer
file only defines functions and performs no probing, file writes or subprocess
calls. All measured deltas are far below the +1000 ms budget in `PLAN.md`.
First-call cost (`list`, `generate`) is where all real work happens, by design.

Absent on this host (zsh, fish, tcsh, ksh, ion, oil, yash, elvish, cmd/clink) are
covered by structural/native-parser checks in `tests/run-tests.sh` and CI.

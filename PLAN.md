# PLAN — Completer universal expansion (GSD-style)

## Goal
Make `completer` a function-based, native-only, zero-startup-cost completion
manager present for every shell in carapace's list except carapace itself, with
sibling folders beside each config file and self-completion of `completer` itself.

## Phase 0 — Stabilize current 8 shells (IN PROGRESS)
- Fix reviewer MAJOR: generated blocks must be idempotent in nu/xsh/bash/zsh/fish/sh
  (skip/refresh existing `# >>> completer:<prog>:<shell> >>>` block before append).
- Fix MINOR: DIAGNOSIS.md stale hash; README xonsh `add_alias`/`remove_alias` names.
- Verify: parsers + isolated-root smoke tests.

## Phase 1 — Research (RUNNING)
- Researcher A: elvish, cmd/clink.
- Researcher B: tcsh, ksh.
- Researcher C: ion, oil, yash.
- Researcher D: folder layout / config paths.
Outputs: `research/<shell>-RESEARCH.md` with official-doc citations + GAPS.

## Phase 2 — Implement 7 new shells (BLOCKED on Phase 1)
Create `completer.{elv,cmd.l,tcsh,ksh,ion,oil,yash}` using ONLY each shell's native
completion API from the research. Each exposes:
`completer <shell> [progs…]`, `alias add/remove`, `list`, `update carapace`, `zoxide`,
plus self-completion registration for `completer` where the shell supports it.

## Phase 3 — Folder structure
For each shell, place `completer.<ext>`, `alias.<ext>`, `completions/` in a sibling
`<config-dir>/completer/` folder. Installers create the folder + one guarded source line.

## Phase 4 — Carapace integration
`update carapace`: detect binary -> `carapace --clear-cache`, `carapace --list`,
`carapace _carapace <shell>`; enable any CLI carapace indexes via `carapace <prog> <shell>`.

## Phase 5 — Review (final gate)
Reviewer audit: code quality, logic bugs, memory, performance, runtime smoke,
docs accuracy. Report BLOCKER/MAJOR/MINOR with file:line. Read-only.

## Constraints
No compiled executable. Zero work at shell load. Backup before overwrite.
Idempotent markers. Max +1000ms startup. Never git push / delete / install.

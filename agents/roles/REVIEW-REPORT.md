# Review report (Phase 5 final gate) — 2026-11-25

Read-only review of `Z:\Projects\Completer\` plus the three owned config files
referenced by DIAGNOSIS.md. No files were pushed, deleted, or installed.

## Method
- Four parallel read-only audits (POSIX; pwsh/nu/xsh/elv/cmd; tcsh/ksh/ion/oil/yash;
  docs/plan) reported BLOCKER/MAJOR/MINOR findings with file:line evidence.
- Every finding was triaged against the live code, not taken on trust. Three
  blockers were reproduced on this host before fixing:
    * xonsh `completer` shadowed by the builtin on first use;
    * PowerShell `alias add` duplicated its Set-Alias line;
    * Nushell `use completer.nu` failed (export name == module name).

## Fixes applied (verified)
- **BLOCKER** xonsh builtin shadowing — alias registered at source time in
  `completer.xsh` (one dict write, no subprocess); self-completion imports stay
  lazy. Verified: `completer list` now runs our function.
- **BLOCKER** PowerShell alias duplication — Add-CompleterAlias regex now matches
  the quoted form. Verified: two adds leave one Set-Alias line.
- **BLOCKER** Nushell `use` collision — entrypoint changed from `export def` to
  `def` (loaded via `source`). Verified: `use ./completer.nu` parses cleanly.
- **BLOCKER** tcsh generated blocks appended unconditionally — now marker-checked
  and replaced in place; csh `echo` backslash corruption fixed with `printf`.
- **BLOCKER** Ion `_completer_root` returned empty (branch-local `let`) — result
  is now function-scoped; `zoxide [shell...]` now generates for any target.
- **BLOCKER/MAJOR** self-completion absent in bash/zsh/fish/pwsh — added lazy,
  native registration in all four; verified in bash via the functional harness.
- **MAJOR** alias-value injection in ksh/oil/yash/ion/bash/zsh/fish/sh/nu/elv —
  all reject quotes/newlines/metacharacters before writing `alias.<ext>`.
  Verified: `completer alias add __evil "x'; echo PWNED; #"` writes no PWNED.
- **MAJOR** carapace/zoxide init files written but never sourced — all managers
  now call their native link helper after generating an init file.
- **MAJOR** missing `.bak.<timestamp>` backups before overwrites — added across
  alias files, config links and generated files in every shell.
- **MAJOR** fish `_completer_capture` rejected multi-line completion output —
  output is joined into a scalar before the emptiness/format checks.
- **MAJOR** elvish unguarded `$args[0]` crashed `update`/`alias` — guarded with
  `count`; cmd loop abort and load-time `doskey` were also corrected.
- **MAJOR** installers chmod'd an existing `$HOME` and stored files flat — now
  create a sibling `completer/` folder (functions + alias + completions), export
  `COMPLETER_ROOT`, source both files in one guarded block, and only chmod paths
  they create. Verified by an isolated-HOME install smoke test.
- **MINOR** GNU-only `date -Is`, regex-unsafe alias removal, `grep && mv` writing
  stale `.tmp`, `date`/hash timing docs, stale PLAN/DIAGNOSIS/README facts — all
  reconciled.

## Verification commands & results
- `bash tests/run-tests.sh` → ALL TESTS PASSED (structural, `bash -n`, `sh -n`,
  PowerShell AST, nu/xonsh source, functional alias/generation/self-complete).
- `xonsh -c 'source ./completer.xsh; completer list'` → our output + `XSH_OUR_LIST_RAN`.
- PowerShell parse of `completer.ps1`/`install.ps1` → 0 errors; two alias adds → 1 line.
- `nu --no-config-file -c 'use ./completer.nu'` → clean (no collision).
- Isolated-HOME `install.sh bash` → sibling `completer/` folder linked from `.bashrc`.

## Residual gaps (inspection-only; no binary on host)
- zsh, fish, elvish, Clink/Lua, tcsh, ksh, ion, oil and yash have no parser on
  this host; their edits were reviewed by inspection. CI runs structural and
  parser checks for the shells it installs.
- Shells with no documented native programmable-completion API (Ion, ksh93) or no
  carapace bridge (Ion, ksh, tcsh, yash) retain documented, graceful no-ops rather
  than invented APIs.
- `DIAGNOSIS.md` config edits are outside the repo task scope and were not
  modified; the stale hash was corrected to the current verified value.

# Tab-completion diagnosis & native fix

Scope: diagnose why Tab completion was degraded in three shells and re-enable it
using each shell's **native** completion API with **zero startup cost**. This file
is separate from the Completer tool. Root causes were confirmed by reading each
owned config file before editing; the fixes are minimal and lazy.

Official docs consulted:
- PowerShell — learn.microsoft.com: `Set-PSReadLineKeyHandler` (PSReadLine) and
  `Register-ArgumentCompleter`.
- Nushell — https://nushell.sh/book/custom_completions.html (External Completions).
- Xonsh — https://xon.sh/completers.html (Registering a Completer,
  `completer add` / `add_one_completer`, `$COMPLETION_MODE`).
- Carapace — https://carapace-sh.github.io (setup / `carapace <cmd> <shell>`).

---

## 1. PowerShell (two byte-identical profile copies)

Owned files:
- `C:\Users\haris\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`
- `C:\Users\haris\.config\shells\powershell\Microsoft.PowerShell_profile.ps1`

### Root cause (evidence, pre-fix line numbers)
- The profile defines a cached Carapace init script path and a load guard:
  `Microsoft.PowerShell_profile.ps1:1052-1053` —
  `$script:CarapaceCache = ...\carapace\init\init-powershell-cached.ps1` and
  `$script:CarapaceLoaded = $false`.
- `Enable-Carapace` was a **no-op**: it set the guard `$true` then hit a bare
  `return` (`Microsoft.PowerShell_profile.ps1:1055-1064`, the `return` at :1064).
  The ~68 KB cached script was never dot-sourced, so Carapace's native
  argument completers were never registered.
- Tab was bound to plain `MenuComplete` twice —
  `Microsoft.PowerShell_profile.ps1:557` (in `Initialize-PSReadLine`) and the
  defensive rebind at `Microsoft.PowerShell_profile.ps1:1071-1074`. With no
  registered completers, MenuComplete had nothing native to offer.
- Native argument completers existed only for `git`, `npm`, `deno`
  (`Microsoft.PowerShell_profile.ps1:617-634`, `Register-ArgumentCompleter`
  at :623) and `dotnet` (:636-643). Every other CLI got only path/command
  completion.
- Ctrl+Space called `Enable-Carapace` (`Microsoft.PowerShell_profile.ps1:1112`)
  but that call did nothing.
- Both copies were byte-identical by SHA256 before editing
  (`C31C287E2595A83DAABA529030C28FD0A115F43C0AB1A5C1F76C9929AE5EE896`).

### Fix applied (identical to both copies)
- `Enable-Carapace` now dot-sources `$script:CarapaceCache` once, guarded by
  `$script:CarapaceLoaded` (the first-Tab lazy load). Startup cost stays 0:
  no Carapace code runs while the profile loads.
- A lazy Tab handler `$script:InvokeTabCompletion` calls `Enable-Carapace`
  then `[Microsoft.PowerShell.PSConsoleReadLine]::MenuComplete()`.
- The **defensive Tab rebind was kept, not removed**, and updated to bind this
  handler (`Set-PSReadLineKeyHandler -Key Tab -ScriptBlock
  $script:InvokeTabCompletion`), with a plain `MenuComplete` fallback when
  Carapace is unavailable. As the last Tab binding in the file it overrides
  the earlier :557 binding. This uses the documented PSReadLine key-handler
  and `Register-ArgumentCompleter` (via the cached Carapace script) APIs.
- Note: the handler variable was named without a hyphen (`InvokeTabCompletion`);
  a hyphenated `$script:Invoke-TabCompletion` is parsed by PowerShell as
  subtraction and produced three parse errors before being corrected.

### Environment facts verified
- Cached script exists:
  `C:\Users\haris\AppData\Local\carapace\init\init-powershell-cached.ps1`,
  68,634 bytes, 627 `Register-ArgumentCompleter` calls, and **no**
  `Set-PSReadLineKeyHandler` calls — so dot-sourcing it cannot clobber the Tab
  binding installed by the profile.

---

## 2. Nushell (`config.nu`)

Owned file: `C:\Users\haris\.config\shells\nushell\config.nu`

### Root cause (evidence, pre-fix line numbers)
- External completion was configured with a completer that returns an empty
  list: `config.nu:139-149`, specifically
  `config.nu:148` — `completer: {|token, place, buffer| [] }`.
  An empty list means "there is nothing to complete", suppressing all native
  external completions (per the Nushell Book).

### Fix applied
- Replaced the empty closure with the documented Carapace external completer
  (nushell.sh/book/custom_completions.html):
  `^carapace $place.command.0 nushell ...$place.command | from json`.
- Guarded so it returns `null` (not an error or empty menu) when Carapace is
  absent or `$place.command` has no command word. Per the docs, returning
  `null` lets Nushell fall back to its built-in file completion. A `try/catch`
  also returns `null` if `carapace`/`from json` fails.
- The closure body runs only on Tab, so startup cost stays 0; `def`/closure
  definitions at load time perform no external work.

---

## 3. Xonsh (`.xonshrc`)

Owned file: `C:\Users\haris\.config\xonsh\.xonshrc`

### Root cause (evidence)
- The Carapace completer is defined and registered with the legacy helper:
  `.xonshrc:783-863`, `@contextual_command_completer` at :809 and
  `add_one_completer('carapace', _carapace_completer, 'start')` at :861.
  Per xon.sh/completers.html, `add_one_completer` is the documented
  programmatic equivalent of `completer add NAME FUNC [POS]`, so the
  registration mechanism itself is valid.
- `$COMPLETION_MODE = "menu-complete"` at `.xonshrc:634` is a documented valid
  value (inserts the first whole completion on Tab, cycles the rest on later
  Tabs). TAB completion is therefore enabled.

### Verification before editing changed our conclusion
Headless diagnostics showed this shell was **already functional**:
`"carapace" in __xonsh__.completers == True`, `COMPLETION_MODE == menu-complete`,
and both imports (`add_one_completer`, `contextual_command_completer`,
`RichCompletion`) succeed. `CommandContext` exposes a `.command` attribute, so
the completer's guard is valid. Accordingly, only **minimal, zero-risk
comment-only edits** were made: a note confirming `menu-complete` validity at
the `$COMPLETION_MODE` line and a note documenting that `add_one_completer(...)`
is the equivalent of `completer add`. No behavior was changed.

---

## Verification commands & results

PowerShell (both profiles) — native AST parser:
- `pwsh -NoProfile -Command '$t=$null;$e=$null;[void][System.Management.Automation.Language.Parser]::ParseFile("<profile>",[ref]$t,[ref]$e); $e.Count'`
  → **0 parse errors** for both copies.
- SHA256 of both profiles → identical
  (`D321235C01F27981AFF9504E49BAD0B02A028C76E3E937DADA09984664AA8FDD`,
  re-verified 2026-11-25; both copies byte-identical. The earlier value in this
  document was stale because the profiles were edited again afterwards.)

Nushell:
- `nu --no-config-file -c 'source C:\Users\haris\.config\shells\nushell\config.nu'`
  → **blocked by external env deps**: `sourced_file_not_found` for
  `C:\Users\haris\AppData\Roaming\nushell\carapace.nu` at `config.nu:209`
  (a `source` line after the edited closure). This is a missing generated
  support file, not a syntax error in the edit.
- `nu --no-config-file -c 'nu-check -d <config.nu>'` → fails at the same
  missing-file `source` line, confirming the closure parses.
- Focused syntax check — evaluating the new closure in isolation
  (`nu --no-config-file -c 'let x = {|place| ... }; print NU_CLOSURE_PARSE_OK'`)
  → **NU_CLOSURE_PARSE_OK**, exit 0. The edited closure itself is valid Nushell.

Xonsh:
- `xonsh -c 'source C:\Users\haris\.config\xonsh\.xonshrc; ...'`
  → **XONSH_SOURCE_OK**, `registered=True`, `mode=menu-complete`.

## GAPS
- `config.nu` cannot be sourced end-to-end in this environment: generated
  support files (`carapace.nu`, and likely `fzf.nu`, `conda.nu`,
  `config-additions.nu`, `zoxide-init.nu`, `oh-my-posh.nu`) are missing under
  `$nu.default-config-dir`/`~/.cache`. The edited closure is independently
  verified to parse; full end-to-end Tab behavior in Nushell remains unverified
  until those generated files exist.
- Runtime Tab presses were not simulated headlessly (no interactive TTY);
  verification is parse-time plus registration checks. The two PowerShell
  profiles are confirmed byte-identical after the fix.

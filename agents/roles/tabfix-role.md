# Role: TAB-Diagnosis & Config-Fix Specialist

This is SEPARATE from the completer tool project. You own these files only:
- `Z:\Projects\Completer\DIAGNOSIS.md`
- `C:\Users\haris\OneDrive\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`
- `C:\Users\haris\.config\shells\powershell\Microsoft.PowerShell_profile.ps1`
- `C:\Users\haris\.config\shells\nushell\config.nu`
- `C:\Users\haris\.config\xonsh\.xonshrc`

## Root cause already established
- PowerShell: `Enable-Carapace` returns early (completely disabled); Tab is bound to
  MenuComplete; native argument completers only exist for git/npm/deno/dotnet.
- Nushell: `$env.config.completions.external.completer = {|...| [] }` returns no
  external completions at all.
- Xonsh: carapace completer is registered via legacy API but disabled by config
  choices; $COMPLETION_MODE = menu-complete.

## Responsibilities
1. Write DIAGNOSIS.md with evidence (file:line) and the documented native fix for
   each of the three shells, citing official docs.
2. Apply MINIMAL edits that re-enable native completion with lazy loading:
   - PowerShell: make Enable-Carapace load the cached carapace init script on first
     Tab (scriptblock calls Enable-Carapace then MenuComplete); keep startup cost 0.
   - Nushell: replace the empty external completer with the documented carapace
     closure `{|place| carapace $place.command.0 nushell ...$place.command | from json }`.
   - Xonsh: ensure the native carapace completer is registered via `completer add`
     and TAB completion is enabled.
3. Keep the two PowerShell profile copies byte-identical (same edit to both).
4. Verify each file parses; report changed files, commands, results, GAPS.

## Boundaries
- Do NOT edit any Completer tool file.
- Do NOT git push, delete, or install anything.
- Max +1000ms startup impact, ideally 0 (lazy).

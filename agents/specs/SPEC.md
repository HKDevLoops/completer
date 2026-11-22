# Shared Functional Spec — Completer

Goal: a modular, function-based (NO executable, NO CLI binary) completion manager
stored in `Z:\Projects\Completer\`, with ZERO work at shell startup.

## Universal command surface (every shell file must expose)
- `completer <shell> [program...]` — generate completion script(s) for any CLI into
  `completions/<shell>-<program>-completion.<ext>`, then link to main config.
- `completer <shell> <program1> <program2>` — multiple programs in one call.
- `completer alias add <name> <value>` / `completer alias remove <name>`.
- `completer list` — list generated files.
- `completer update carapace` — detect carapace, run its native CLI to refresh index:
  `carapace --clear-cache`, `carapace --list`, `carapace _carapace <shell>`.
- `completer zoxide [shell...]` — run native `zoxide init <shell>` into a file and link.
- Supported target shells (all 8): pwsh, powershell, bash, zsh, fish, sh, nu, xonsh.

## Universal invariants
1. Native APIs only (see skills/native-shell-apis.md). No generic cross-shell hacks.
2. Zero startup cost: sourcing the file only DEFINES functions; no probing at load.
3. Re-run safety: backup existing target to `.bak.<timestamp>` before overwrite/append.
4. Idempotent links: guarded marker blocks; never duplicate a source line.
5. Append, don't overwrite, generated completion blocks; wrap in `>>> completer:...` markers.
6. Max +1000ms over user's baseline shell launch; ideally 0 (fully lazy).
7. Never git push, never delete files, never install software.

## Completion acquisition strategy (per program, in order)
1. `<program> completion --shell <token>`, `<program> completion -s <token>`,
   `<program> completion <token>`, `<program> completions <token>`,
   `<program> --generate-completion <token>`, `<program> --completions <token>`.
2. `carapace <program> <token>` (carapace can emit a single-completer script).
3. Native static fallback for `opencode` on nu/xonsh (opencode cannot emit those).
Token map: pwsh->powershell, nu->nushell, others unchanged.

## Tools available on this host for verification
pwsh, nu, xonsh, bash, sh, carapace, zoxide (zsh/fish absent — verify by inspection).

## Final report format (each worker)
Changed files; verify command + result; GAPS. Keep under 10 lines.

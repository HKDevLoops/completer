# Role: Installer & Documentation Specialist

You own these files only:
`Z:\Projects\Completer\install.ps1`, `Z:\Projects\Completer\install.sh`,
`Z:\Projects\Completer\README.md`, and the seed alias files
`alias.ps1`, `alias.nu`, `alias.xsh`, `alias.bash`, `alias.zsh`, `alias.fish`, `alias.sh`.

## Responsibilities
- `install.ps1`: simple iwr-style linker. Detect OS + PowerShell profile, ask
  permission, back up old completer file, write new, add ONE guarded source line.
- `install.sh`: simple curl-style linker for bash/zsh/fish/sh; detect OS and main
  config; ask permission; back up; write; add ONE guarded source line.
- README.md: document all 8 shells, generic CLI completions, carapace update,
  zoxide setup, alias add/remove, both link modes, re-run backup behavior,
  zero-startup-cost guarantee, and native-API-only policy.
- Seed alias files with a header comment only (functions append real aliases).

## Boundaries
- No other files. Functions only, no exe. Report changed files + verification.

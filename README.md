```
 ██████╗ ██████╗ ███╗   ███╗███████╗████████╗███████╗███╗   ██╗████████╗███████╗
██╔════╝██╔═══██╗████╗ ████║██╔════╝╚══██╔══╝██╔════╝████╗  ██║╚══██╔══╝██╔════╝
██║     ██║   ██║██╔████╔██║█████╗     ██║   █████╗  ██╔██╗ ██║   ██║   █████╗
██║     ██║   ██║██║╚██╔╝██║██╔══╝     ██║   ██╔══╝  ██║╚██╗██║   ██║   ██╔══╝
╚██████╗╚██████╔╝██║ ╚═╝ ██║███████╗   ██║   ███████╗██║ ╚████║   ██║   ███████╗
 ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝
```

# completer

**A tiny function. Every shell. Completions that just work.**

`completer` is a **function-based, native-only** completion + alias manager for
every shell in carapace's family. No binary. No daemon. No startup tax.

> It's a simple function for users to add completions — and append them.
> It automatically indexes with **carapace**, so the **next launch of your shell**
> just starts working.

---

## Philosophy

- **Native APIs only** — each shell uses its own documented completion API.
- **Zero startup cost** — sourcing only *defines* functions. No probing at load.
- **Modular** — main config keeps ONE guarded source line; everything else lives
  in a sibling `completer/` folder next to your shell config.
- **Re-run safe** — backups + idempotent markers; never duplicates a definition.

## Supported shells (15)

`pwsh` · `powershell` (5.1) · `bash` · `zsh` · `fish` · `sh` · `nu` · `xonsh` ·
`elvish` · `cmd` (clink) · `tcsh` · `ksh` · `ion` · `oil` · `yash`

*(carapace itself is the engine, not a target.)*

## Install (simple)

```powershell
$env:COMPLETER_RAW_BASE='https://raw.githubusercontent.com/harish2222/completer/main'
iwr "$env:COMPLETER_RAW_BASE/install.ps1" | iex
```
```sh
export COMPLETER_RAW_BASE=https://raw.githubusercontent.com/harish2222/completer/main
curl -fsSL "$COMPLETER_RAW_BASE/install.sh" | sh -s bash
```

The installer detects your OS + config file, asks permission, backs up the old
file, writes a new `completer.<ext>`, and adds ONE guarded source line.

## Sample commands

```sh
completer bash opencode gh docker     # generate completions from any CLI
completer update carapace             # refresh carapace's index
completer zoxide                      # native zoxide cd init
completer alias add gs 'git status'   # append an alias
completer alias remove gs             # remove it
completer list                        # list generated completion files
completer pwsh                        # target a specific shell
```

`completer` completes **its own** arguments too — subcommands, shell names, and
aliases, natively in every shell that supports self-completion.

## Layout

```
~/.config/completer/         <- companion config (TAB fix + library + self-completion)
  alias.<ext>                <- alias store (append/remove methods)
  completions/               <- generated per-CLI scripts (backup + markers)
Z:\Projects\Completer\       <- source repo (all functions + research + CI)
```

## License

MIT — see [LICENSE](LICENSE). Copyright (c) 2026 harish2222 (HKDEVS).

```
 ██████╗ ██████╗ ███╗   ███╗███████╗████████╗███████╗███╗   ██╗████████╗███████╗
██╔════╝██╔═══██╗████╗ ████║██╔════╝╚══██╔══╝██╔════╝████╗  ██║╚══██╔══╝██╔════╝
██║     ██║   ██║██╔████╔██║█████╗     ██║   █████╗  ██╔██╗ ██║   ██║   █████╗
██║     ██║   ██║██║╚██╔╝██║██╔══╝     ██║   ██╔══╝  ██║╚██╗██║   ██║   ██╔══╝
╚██████╗╚██████╔╝██║ ╚═╝ ██║███████╗   ██║   ███████╗██║ ╚████║   ██║   ███████╗
 ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝
```

# completer

[![ci](https://github.com/HKDevLoops/completer/actions/workflows/ci.yml/badge.svg)](https://github.com/HKDevLoops/completer/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![shells](https://img.shields.io/badge/shells-15-green.svg)](#supported-shells)

> **One small function. Fifteen shells. Zero startup tax.**
>
> Tired of Googling "how to enable tab completion in *yet another shell*" every
> time you switch terminals? Same. So `completer` bundles the native completion
> glue for every shell in one lazy, modular place — then gets out of your way.

This is **not** a CLI you install. **Not** a binary. **Not** a daemon that eats your RAM
for breakfast. It's a **shell function** per shell, written in that shell's own
native language, that generates completions from any program and wires them into
your config — only when you ask it to.

---

## The vibe

- 🧠 **Native-only.** Every shell uses its own documented API. No cross-shell hacks,
  no `eval` soup, no wrapper executable.
- ⚡ **Zero startup cost.** Sourcing the file only *defines functions*. No probing,
  no `carapace`/`zoxide` calls, no file writes at load. Your shell opens exactly as
  fast as it did before.
- 🧩 **Modular by design.** Your main config keeps **one guarded source line**.
  Everything else lives in a sibling `completer/` folder next to it.
- 🛡️ **Re-run safe.** Existing files are backed up to `.bak.<timestamp>`; generated
  blocks are marker-wrapped and replaced, never duplicated. Idempotent or bust.
- 🔌 **Plugs into carapace & zoxide.** `completer update carapace` refreshes the index
  using carapace's own CLI; `completer zoxide` emits native `cd` init. Next shell
  launch, it just works.
- 🤖 **Self-aware.** `completer` completes **its own** subcommands, shell names,
  and aliases. (A completion tool that can't complete itself? What's the point.)

---

## Supported shells

| Shell | File | Shell | File |
|---|---|---|---|
| PowerShell 7+ (`pwsh`) | `completer.ps1` | Elvish | `completer.elv` |
| Windows PowerShell 5.1 | `completer.ps1` | Cmd (`cmd.exe` + clink) | `completer.cmd.l` |
| Bash | `completer.bash` | Tcsh / csh | `completer.tcsh` |
| Zsh | `completer.zsh` | Ksh (ksh93 / mksh) | `completer.ksh` |
| Fish | `completer.fish` | Ion | `completer.ion` |
| POSIX sh | `completer.sh` | Oil (`osh` / `ysh`) | `completer.oil` |
| Nushell | `completer.nu` | Yash | `completer.yash` |
| Xonsh | `completer.xsh` | **Carapace** | *the engine, not a target* |

---

## Install (30 seconds)

Set the raw base once, then pipe the installer. It detects your OS + config file,
asks permission, backs up, writes the new function file, and adds **one** guarded
source line. (Yes, it's polite.)

**PowerShell (7+ / 5.1):**
```powershell
$env:COMPLETER_RAW_BASE = 'https://raw.githubusercontent.com/HKDevLoops/completer/main'
iwr "$env:COMPLETER_RAW_BASE/install.ps1" | iex
# Windows PowerShell 5.1: irm "$env:COMPLETER_RAW_BASE/install.ps1" | iex
```

**bash / zsh / fish / sh:**
```sh
export COMPLETER_RAW_BASE=https://raw.githubusercontent.com/HKDevLoops/completer/main
curl -fsSL "$COMPLETER_RAW_BASE/install.sh" | sh -s bash   # or zsh | fish | sh
```

Prefer local? `sh ./install.sh` or `. .\install.ps1` from the repo root works too.

---

## Usage — the good stuff

```sh
completer bash opencode gh docker     # ask any CLI for its completions
completer pwsh                        # target one shell (defaults to opencode)
completer update carapace             # refresh carapace's completion index
completer zoxide                      # native zoxide `cd` init
completer alias add gs 'git status'   # append an alias to alias.<ext>
completer alias remove gs             # ...and take it back out
completer list                        # show what's been generated
```

**Completion sources, in order:** the program's own flags
(`completion --shell`, `--completions`, …) → `carapace <prog> <shell>` → a built-in
native spec for shells a tool can't target directly (looking at you, `opencode` on
`nu`/`xonsh`).

**Link modes:** `Source` (default — one guarded `source` line) or `-LinkMode Symlink`
(for the symlink-inclined). `-NoLink` generates without touching your config.

---

## How it stays out of your way

```
your shell config ──(one guarded source line)──▶ .config/completer/setup-<shell>.<ext>
                                                      │
                                                      ├─ TAB fix (lazy carapace)
                                                      ├─ sources completer.<ext>
                                                      └─ self-completion hook
                                                             │
                                                             ▼
                                                  completions/<shell>-<prog>-completion.<ext>
                                                             ▲
                                       generated on demand, backed up, marker-wrapped
```

Nothing runs until you call `completer`. Promise. 🤞

---

## Project layout

```
completer.<ext>          # 15 native function implementations
install.ps1 / install.sh # simple, curl/iwr-friendly linkers
alias.<ext>              # per-shell alias stores (append/remove methods)
tests/run-tests.sh       # structural + native-parser test harness
.github/workflows/ci.yml # GitHub Actions: ubuntu + windows
research/                # official-doc studies behind each native API
agents/                  # role / skill / spec files used to build this
DIAGNOSIS.md             # why TAB completion was "broken" and how it's fixed
PLAN.md                  # the build plan
LICENSE                  # MIT
```

---

## Testing

```sh
bash tests/run-tests.sh
```

Runs structural checks (files, entrypoints, no compiled binaries) plus native
parsers for whichever shells are installed (`bash -n`, `sh -n`, PowerShell parser,
`nu`, `xonsh`). CI runs the same harness on both Ubuntu and Windows. All green. ✅

---

## License

MIT — do whatever you want, just keep the notice. See [LICENSE](LICENSE).

Copyright © 2026 harish2222 (HKDEVS). Built with native shell glue and a mild
allergy to startup lag.

# Folder Layout / Config Paths — Researcher D

Scope: main config-file path and the required sibling `completer/` folder for every
shell in carapace's list **except carapace**: pwsh, powershell 5.1, bash, zsh, fish,
nu, xonsh, elvish, cmd, tcsh, ksh, ion, oil, yash.

Method: official docs only (project sites, project-hosted manuals, learn.microsoft.com,
gnu.org, fishshell.com, nushell.sh, xon.sh, elv.sh, chrisant996.github.io/clink,
carapace-sh.github.io). Host inspected read-only; nothing modified. No speculation.

## 1. Foundational definition: `UserConfigDir` (carapace)

Per carapace's setup docs [C2], `UserConfigDir` (Go `os.UserConfigDir`) is:

> - On **Unix** systems, it returns `$XDG_CONFIG_HOME` ... if non-empty, else `$HOME/.config`.
> - On **Darwin**, it returns `$HOME/Library/Application Support`.
> - On **Windows**, it returns `%AppData%`.
> - On **Plan 9**, it returns `$home/lib`.

Carapace's own config dir additionally honours `$XDG_CONFIG_HOME` on every OS.
Carapace's per-shell setup snippets [C1] express RC paths in terms of this variable;
those are the authoritative "UserConfigDir paths" requested for this research.

## 2. Main table

`<config-dir>` = directory containing the shell's main config file. The sibling folder
is always `<config-dir>/completer/`, at the **same level as the config file** (details
in §4). `<ext>` = that shell's native script suffix.

| shell | config path (Win) | config path (POSIX) | sibling folder | citation |
|---|---|---|---|---|
| pwsh (PowerShell 7) | `%AppData%\powershell\Microsoft.PowerShell_profile.ps1` (carapace UserConfigDir). MS default: `$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` | `~/.config/powershell/Microsoft.PowerShell_profile.ps1` (MS); carapace: `$XDG_CONFIG_HOME/powershell/Microsoft.PowerShell_profile.ps1` | `<config-dir>\completer\` (default: `%AppData%\powershell\completer\`) | [C1] Powershell section; [C2]; [M1] CurrentUserCurrentHost bullet |
| powershell 5.1 (Windows PowerShell) | `$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` | N/A — Windows PowerShell 5.1 is Windows-only; no POSIX path documented | `$HOME\Documents\WindowsPowerShell\completer\` | [M1] Invoke-Command example uses `$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`; "Other Supported Versions" lists `powershell-5.1` |
| bash | `~/.bashrc` under MSYS2/Git-Bash/WSL (`%USERPROFILE%\.bashrc`); carapace uses `~/.bashrc` | `~/.bashrc` (interactive non-login); login: `~/.bash_profile`, `~/.bash_login`, `~/.profile` | `<config-dir>/completer/` → `~/.completer/` (home-level, beside `.bashrc`) | [C1] Bash section (`# ~/.bashrc`); [G1] Bash Startup Files |
| zsh | `%AppData%\zsh\.zshrc` (carapace UserConfigDir) | `$ZDOTDIR/.zshrc` (interactive); if `ZDOTDIR` unset, `HOME` is used → `~/.zshrc`. Carapace: `$XDG_CONFIG_HOME/zsh/.zshrc` | `<config-dir>/.completer/` beside `.zshrc` → `~/.completer/` (ZDOTDIR unset) or `$XDG_CONFIG_HOME/zsh/completer/` | [C1] Zsh section; [C2]; [Z1] Files / Startup-Shutdown Files |
| fish | `%AppData%\fish\config.fish` (carapace UserConfigDir) | `~/.config/fish/config.fish` (`$XDG_CONFIG_HOME/fish/config.fish`); carapace: `$XDG_CONFIG_HOME/fish/config.fish` | `<config-dir>/completer/` → `~/.config/fish/completer/` | [C1] Fish section; [C2]; [F1] (completions dir `~/.config/fish/completions/`) |
| nu (Nushell) | `%AppData%\nushell\config.nu` (carapace); `$nu.default-config-dir` = `C:\Users\me\AppData\Roaming\nushell` | `$nu.default-config-dir`: Linux `~/.config/nushell`, macOS `~/Library/Application Support/nushell`; files `env.nu`, `config.nu`, `login.nu`; `XDG_CONFIG_HOME` override | `<config-dir>/completer/` → `%AppData%\nushell\completer\` / `~/.config/nushell/completer/` | [C1] Nushell section; [C2]; [N1] Configuration Overview (`$nu.default-config-dir`) |
| xonsh | `%AppData%\xonsh\rc.xsh` (carapace UserConfigDir); xonsh system dir `%ALLUSERSPROFILE%\xonsh` | `$XONSHRC` default `[…, '$XONSH_CONFIG_DIR/xonsh/rc.xsh', '~/.xonshrc']`; `$XONSH_CONFIG_DIR` = `$XDG_CONFIG_HOME/xonsh` (default `~/.config`) | `<config-dir>/completer/` → `$XONSH_CONFIG_DIR/completer/` (default `~/.config/xonsh/completer/`) | [C1] Xonsh section; [C2]; [X1] `$XONSHRC`, `$XONSH_CONFIG_DIR`, `$XDG_CONFIG_HOME`, `$XONSH_SYS_CONFIG_DIR` |
| elvish | `%AppData%\elvish\rc.elv` (native + carapace) | `~/.config/elvish/rc.elv`; `$XDG_CONFIG_HOME/elvish/rc.elv` if set; legacy `~/.elvish/rc.elv` | `<config-dir>/completer/` → `~/.config/elvish/completer\` / `%AppData%\elvish\completer\` | [C1] Elvish section; [C2]; [E1] §2.1 RC file |
| cmd (cmd.exe via Clink) | `%LOCALAPPDATA%\clink\` — docs: `c:\Users\username\AppData\Local\clink`; carapace places `carapace.lua` there (`~/AppData/Local/clink/carapace.lua`) | N/A — cmd.exe/Clink are Windows-only; no POSIX path | `%LOCALAPPDATA%\clink\completer\` | [C1] Cmd section; [K0] File Locations ("Windows Vista onwards: `c:\Users\username\AppData\Local\clink`") |
| tcsh | `~/.tcshrc` under Cygwin/MSYS2 (no native Windows tcsh documented) | `~/.tcshrc` | `<config-dir>/completer/` → `~/.completer/` (beside `.tcshrc`) | [C1] Tcsh section (`# ~/.tcshrc`); official tcsh man page unreachable — see GAPS |
| ksh | `~/.kshrc` under Cygwin/MSYS2 (ksh93u+m builds on Cygwin [K1]) | `~/.kshrc` (home-level, `ENV`-style rc); login `~/.profile`. Note: official docs retrieved only confirm the system rc `/etc/ksh.kshrc` — the user rc path is a host-file observation, not a doc citation | `<config-dir>/completer/` → `~/.completer/` (beside `.kshrc`) | [K1] ksh93u+m README (Cygwin support, `/etc/ksh.kshrc`); host file `C:\Users\haris\.kshrc`; see GAPS |
| ion | No Windows port documented (manual: "currently searching for a Windows developer to port it to Windows") | `~/.config/ion/initrc` (XDG); `$XDG_CONFIG_HOME/ion/initrc` override | `<config-dir>/completer/` → `~/.config/ion/completer/` | [I1] Script Executions / "Executing commands at start of interactive ion session" |
| oil (osh/ysh) | `%AppData%\oil\oshrc` (carapace UserConfigDir) | `$XDG_CONFIG_HOME/oil/oshrc` (i.e. `~/.config/oil/oshrc`) | `<config-dir>/completer/` → `$XDG_CONFIG_HOME/oil/completer/` | [C1] Oil section (`${UserConfigDir}/oil/oshrc`); [C2]; official oil docs URL returned 404 — see GAPS |
| yash | Not documented — official site unreachable, no carapace setup entry | Not documented — official site unreachable, no carapace setup entry | Not determinable from official docs — see GAPS | none (yash.osdn.jp returned 500 / expired domain; see GAPS) |

## 3. Host inspection (read-only) — `C:\Users\haris\.config`

Actual directories/files found (`Get-ChildItem -Force`):

- `C:\Users\haris\.config\shells\nushell\` — **nu config PRESENT**: `config.nu`, `env.nu`,
  `carapace.nu`, `completions/`, plus `modules/`, `vendor/`. This is a **custom**
  location (`XDG`-style `.config/shells/<shell>/`), not the documented default
  `%AppData%\nushell\`.
- `C:\Users\haris\.config\shells\powershell\` — **pwsh config PRESENT**:
  `Microsoft.PowerShell_profile.ps1`, `profile.ps1`, `powershell.config.json`,
  plus `Modules/`, `Scripts/`. Custom location, not the MS default
  `Documents\PowerShell\`.
- `C:\Users\haris\.config\shells\xonsh\` — **xonsh config PRESENT**: `rc.xsh`,
  `.xonshrc`, `init.xsh`, `modules/aliases.xsh`. Custom location, not the
  documented `$XONSH_CONFIG_DIR` (`~/.config/xonsh`).
- `C:\Users\haris\.config\completer\completions\` — exists but **empty** (only the
  `completions/` subfolder). This is a single global completer folder at `.config`
  level, **not** a per-shell sibling folder.
- `C:\Users\haris\.config\carapace\` — carapace present (`config.yaml`, `specs/`).
  Out of scope (carapace excluded), recorded for completeness.
- Home-level dotfiles found in `C:\Users\haris\`: `.bashrc`, `.bash_profile`,
  `.zshrc`, `.tcshrc`, `.kshrc`, `.xonshrc` → **bash, zsh, tcsh, ksh, xonsh**
  configs also present at their documented home-level defaults (`~`).
- **Not found** in inspected locations: fish (`config.fish`), elvish (`rc.elv`),
  Clink (`%LOCALAPPDATA%\clink\`), ion (`initrc`), oil (`oshrc`), yash (`.yashrc`).
  These are INSPECTION-ONLY / absent on this host.
- **No `<config-dir>/completer/` sibling folder exists yet** under any of the
  shell directories above; only the global `C:\Users\haris\.config\completer\`
  exists. Note for implementation: the required convention (§4) is per-shell.

## 4. Required sibling-folder convention

For every shell, place a folder named `completer/` **inside the directory that
contains that shell's main config file**, i.e. as a sibling entry at the same level:

```
<config-dir>/
├── <shell config file>        # e.g. config.nu, rc.xsh, .zshrc, .bashrc, oshrc
└── completer/
    ├── completer.<ext>        # generated completer/self-completion script
    ├── alias.<ext>            # generated alias script
    └── completions/           # generated per-command completion files
```

`<ext>` is the shell's native script suffix (documented suffixes: `.ps1` PowerShell,
`.nu` Nushell, `.xsh` Xonsh, `.elv` Elvish, `.lua` Clink; `.fish` fish). For
bash/zsh/tcsh/ksh/ion/oil/yash the suffix is a project naming convention, not
mandated by the shell docs. The single global `C:\Users\haris\.config\completer\`
currently on this host does **not** satisfy this per-shell convention.

## 5. Sources

- [C1] carapace-bin Setup — https://carapace-sh.github.io/carapace-bin/setup.html
- [C2] carapace-bin UserConfigDir — https://carapace-sh.github.io/carapace-bin/setup/userConfigDir.html
- [M1] Microsoft Learn, about_Profiles — https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles
- [G1] GNU Bash Manual, Bash Startup Files — https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html
- [Z1] Zsh Manual, Files (5.1 Startup/Shutdown Files, 5.2 Files) — https://zsh.sourceforge.io/Doc/Release/Files.html
- [F1] fish docs, Interactive use — https://fishshell.com/docs/current/interactive.html (completions: `~/.config/fish/completions/<name>.fish`)
- [N1] Nushell Book, Configuration — https://www.nushell.sh/book/configuration.html
- [X1] Xonsh docs, Environment Variables — https://xon.sh/envvars.html
- [E1] Elvish reference, The Elvish command (§2.1 RC file) — https://elv.sh/ref/command.html
- [K0] Clink docs, File Locations — https://chrisant996.github.io/clink/clink.html
- [I1] Ion Manual, Script Executions — https://doc.redox-os.org/ion-manual/scripts.html
- [K1] ksh93u+m project README — https://github.com/ksh93/ksh
- Host inspection: `C:\Users\haris\.config\` and `C:\Users\haris\` (read-only, this session)

## GAPS

- **yash**: no official config-path doc retrieved. `yash.osdn.jp/doc/` → HTTP 500,
  `yash.osdn.jp/doc/yash.html` → 500, `yash.osdn.jp/` → expired-domain placeholder.
  Web search unavailable (HTTP 402). Carapace setup page has no yash entry. No path
  asserted; needs a reachable official yash manual before implementation.
- **ksh**: official user RC path not confirmed. `kornshell.com` and
  `kornshell.com/doc/ksh93.html` unreachable (transport error). The ksh93u+m README
  confirms only the system rc `/etc/ksh.kshrc` and Cygwin support. `~/.kshrc` in the
  table is a host-file observation, not an official-doc citation; confirm via a
  project-hosted ksh93/mksh man page.
- **oil**: official oilshell.org doc URLs (`/release/latest/doc/osh-usage.html`,
  `/release/0.31.0/doc/...`, `/release/latest/doc/`) returned 404; oils.pub likewise.
  Only the carapace setup path (`${UserConfigDir}/oil/oshrc`) is cited.
- **tcsh**: official tcsh man page unreachable (`ftp.astron.com/tcsh.man.html`
  transport error; web search 402). Only the carapace setup path (`~/.tcshrc`) cited;
  no project-hosted tcsh manual corroboration.
- **cmd/Clink POSIX**: N/A — no POSIX variant exists; recorded as N/A, not a gap.
- **powershell 5.1 POSIX**: N/A — Windows-only; recorded as N/A, not a gap.
- **Host-vs-doc divergence**: pwsh, nu, xonsh use custom `.config/shells/<shell>/`
  paths on this host, contradicting their documented defaults. Any installer must
  resolve the actual `$PROFILE` / `$nu.default-config-dir` / `$XONSH_CONFIG_DIR`
  at runtime rather than hardcode a default.
- **Web search** was unavailable for the whole session (HTTP 402), limiting discovery
  of alternate official URLs for the gaps above.

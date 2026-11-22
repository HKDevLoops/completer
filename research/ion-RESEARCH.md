# Ion — Official-Docs Research (INSPECTION-ONLY)

> **INSPECTION-ONLY.** All three shells in this research batch (Ion, Oil, Yash) are ABSENT on this
> host. No binary was invoked; every statement below comes from official project documentation only.
> No speculation.

## 1. Config / RC path

- **POSIX (documented):** `~/.config/ion/initrc`.
  - Verbatim: *"The init file for Ion can be found in **$HOME/.config/ion/initrc** on Linux systems; and the history file can be found at **$HOME/.local/share/ion/history**."*
    — https://doc.redox-os.org/ion-manual/general.html#xdg-app-dirs-support (also in https://doc.redox-os.org/ion-manual/print.html)
  - Verbatim: *"Ion reads those initial commands from a file called "initrc". Ion looks for this file in its configuration folder according to the xdg standard. This typically results in the configuration path \~/.config/ion by default. So ion searches for the file initrc in the folder \~/.config/ion normally."*
    — https://doc.redox-os.org/ion-manual/scripts.html#executing-commands-at-start-of-interactive-ion-session
  - Override: *"You can change the location where ion looks for its configuration folder by setting the environmental variable **$XDG_CONFIG_HOME** to a different path."* — same URL.
- **Windows:** NOT documented. The official README states the shell is not ported: *"While it is developed alongside, and primarily for, RedoxOS, it is a fully capable on other \*nix platforms, and we are currently searching for a Windows developer to port it to Windows."* — https://github.com/redox-os/ion (README, Introduction)
- Note: the task brief mentioned `config.ion`; the official manual instead documents `initrc` as the startup file. No `config.ion` path appears in the official docs retrieved.

## 2. Native completion API

**No native programmable completion API is documented.** The official manual has no completion chapter
(full chapter list: https://doc.redox-os.org/ion-manual/), and the builtin list contains no
`complete` / `compgen` / completion-registration builtin (https://doc.redox-os.org/ion-manual/builtins.html).
During completion research the full manual text was searched for "complet": the only matches were
"feature-complete", "complete filename", "Complete List of Conditional Builtins", and the `which`
builtin description ("alias/builtin/function/executable that would be executed") — none describe a
completion API (https://doc.redox-os.org/ion-manual/print.html).

No verbatim registration snippet exists in the official docs → see GAPS.

## 3. Alias add / remove (native mechanism)

- **Add** — verbatim from the manual's "Aliases" section:

  ```sh
  alias ls = "ls --color"
  #echo $ls #ion: expansion error: Variable does not exist
  #aliase are stored separately
  ```

  — https://doc.redox-os.org/ion-manual/expansions/01-variable.html#aliases
  (Manual text: *"Ion also supports aliasing commands, which can be defined using the `alias` builtin."*)
- **Remove:** no `unalias` builtin appears in the official builtin list
  (https://doc.redox-os.org/ion-manual/builtins.html). Removal mechanism is undocumented → GAPS.

## 4. Sourcing a generated file

- Verbatim builtin definition:

  ```
  source FILEPATH

  DESCRIPTION
      Evaluates the commands in a specified file in the current shell. All changes in shell
      variables will affect the current shell because of this.
  ```

  — https://doc.redox-os.org/ion-manual/builtins.html#source---evaluates-given-file

## 5. Carapace bridge

**Not documented.** The official carapace setup page lists Bash, Cmd, Elvish, Fish, Nushell, Oil,
PowerShell, Tcsh, Xonsh and Zsh — **no Ion section**
(https://carapace-sh.github.io/carapace-bin/setup.html). → GAPS.

## 6. Zoxide init

**Not documented for Ion.** The official zoxide README lists setup targets: Bash, Elvish, Fish,
Nushell, PowerShell, Tcsh, Xonsh, Zsh, and "Any POSIX shell" — Ion is not listed
(https://github.com/ajeetdsouza/zoxide#setup-zoxide-on-your-shell). Ion's own manual states it is
not POSIX (https://doc.redox-os.org/ion-manual/introduction.html#why-not-posix). → GAPS.

## 7. Self-completion (completion for the shell's OWN `completer` function)

**Not feasible per official docs.** No completion API, no completion-function registration mechanism,
and no carapace bridge are documented for Ion (sources in §2, §5). Therefore no exact snippet can be
given without speculation. → GAPS.

## Sources

1. https://doc.redox-os.org/ion-manual/ (manual index)
2. https://doc.redox-os.org/ion-manual/general.html#xdg-app-dirs-support (initrc path)
3. https://doc.redox-os.org/ion-manual/scripts.html#executing-commands-at-start-of-interactive-ion-session (initrc / XDG_CONFIG_HOME)
4. https://doc.redox-os.org/ion-manual/builtins.html (builtins, source, no completion builtin)
5. https://doc.redox-os.org/ion-manual/expansions/01-variable.html#aliases (alias snippet)
6. https://doc.redox-os.org/ion-manual/print.html (full manual; completion-term search)
7. https://doc.redox-os.org/ion-manual/functions.html (fn/end function syntax)
8. https://doc.redox-os.org/ion-manual/repl.html (PROMPT function, keybindings)
9. https://github.com/redox-os/ion (official README; "Mirror of https://gitlab.redox-os.org/redox-os/ion"; no Windows port)
10. https://carapace-sh.github.io/carapace-bin/setup.html (no Ion section)
11. https://github.com/ajeetdsouza/zoxide (no Ion init section)

## GAPS

- Windows config path: none — official README says no Windows port exists.
- `config.ion`: not documented anywhere in official docs; only `initrc` is documented.
- Native completion registration API: none documented; official manual has no completion chapter/builtin.
- Alias removal: no `unalias` builtin documented; removal mechanism unknown.
- Carapace bridge: not listed on carapace setup page.
- Zoxide init: not listed by zoxide and Ion is non-POSIX; no snippet.
- Self-completion: impossible to specify from official docs; no API to register a completer.
- Web search integration returned HTTP 402 during this research; all findings above came from direct
  fetches of the official URLs listed. Any claim not backed by those URLs was deliberately omitted.

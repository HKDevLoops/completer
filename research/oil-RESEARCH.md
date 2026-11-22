# Oil (osh/ysh) — Official-Docs Research (INSPECTION-ONLY)

> **INSPECTION-ONLY.** All three shells in this research batch (Ion, Oil, Yash) are ABSENT on this
> host. No binary was invoked; every statement below comes from official project documentation only.
> No speculation. Note: the project renamed from "Oil Shell" to "Oils" and moved from `oilshell.org`
> to `oils.pub` in 2025 (https://www.oilshell.org/; docs at https://www.oils.pub/release/latest/doc/).

## 1. Config / RC path

- **POSIX (documented):** `~/.config/oils/oshrc` and `~/.config/oils/yshrc`.
  - Verbatim: *"mkdir -p ~/.config/oils       # for oshrc and yshrc"* and
    *"bin/osh runs ~/.config/oils/oshrc"*, *"bin/ysh runs ~/.config/oils/yshrc"* —
    https://www.oils.pub/release/latest/doc/getting-started.html#your-configuration-dir and
    https://www.oils.pub/release/latest/doc/getting-started.html#initialization-with-rc-files
  - Verbatim: *"If you get tired of typing ~/.config/oils/oshrc, symlink it to ~/.oshrc."* —
    https://www.oils.pub/release/latest/doc/getting-started.html#tips
  - Note: these are the **only** sourced files: *"These are the only files that are 'sourced'."* — same URL.
- **Carapace's documented path differs:** `${UserConfigDir}/oil/oshrc` (note `oil`, not `oils`):
  ```sh
  # ${UserConfigDir}/oil/oshrc
  export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense' # optional
  source <(carapace _carapace)
  ```
  — https://carapace-sh.github.io/carapace-bin/setup.html#oil
- **Windows:** no config path documented in official docs (getting-started is entirely POSIX/XDG).
  → GAPS.

## 2. Native completion API

- API overview — verbatim:

  > "You can use interactive completion directly under `osh` or `ysh`, or clients of a headless
  > shell can use it as an API. ... The completion API is modeled after the bash completion API.
  > However, an incompatibility is that it deals with `argv` entries and not command strings.
  > OSH moves the **responsibility for quoting** into the shell. Completion plugins should not do it."

  — https://www.oils.pub/release/latest/doc/completion.html
  (source: https://raw.githubusercontent.com/oilshell/oil/master/doc/completion.md — page is marked
  "Work in progress" and has a TODO to describe `compadjust`.)
- Registration/generation builtins — verbatim from the Oils Reference, "Completion" chapter:

  > "These builtins implement our bash-compatible autocompletion system.
  > **complete** — Registers completion policies for different commands.
  > **compgen** — Generates completion candidates inside a user-defined completion function. It can
  > also be used in scripts, i.e. outside a completion function.
  > **compopt** — Changes completion options inside a user-defined completion function.
  > **compadjust** — Adjusts `COMP_ARGV` according to specified delimiters, and optionally set
  > variables cur, prev, words (an array), and cword. May also set 'split'. This is an OSH extension
  > that makes it easier to run the bash-completion project.
  > **compexport** — Complete an entire shell command string. For example, `compexport -c 'echo $H'`
  > will complete variables like `$HOME`. And `compexport -c 'ha'` will complete builtins like `hay`,
  > as well as external commands."

  — https://www.oils.pub/release/latest/doc/ref/chap-builtin-cmd.html#completion
- Practical usage evidence: the official blog documents sourcing the ~2000-line bash-completion
  main script and ~3000-line `git-completion.bash` under OSH, with a verbatim `_filedir()` completion
  function using `compgen` and `compopt` — https://www.oilshell.org/blog/2018/10/10.html
  (Appendix A). This confirms bash-style completion functions are supported.

## 3. Alias add / remove (native mechanism)

Verbatim from the Oils Reference "Interactive" chapter:

```
alias NAME=CODE
```
"Make NAME a shortcut for executing CODE, e.g. `alias hi='echo hello'`."

```
alias NAME
```
"Show the value of this alias."

```
alias
```
"Show a list of all aliases."

Removal:
```
unalias NAME
```
"Remove the alias NAME."

— https://www.oils.pub/release/latest/doc/ref/chap-builtin-cmd.html#alias and
https://www.oils.pub/release/latest/doc/ref/chap-builtin-cmd.html#unalias

## 4. Sourcing a generated file

Verbatim from the reference:

```
source SCRIPT ARG*
```
"Execute SCRIPT with the given ARGs, in the context of the current shell. That is, existing variables
will be modified."
— https://www.oils.pub/release/latest/doc/ref/chap-builtin-cmd.html#source

Carapace uses process substitution specifically (verbatim): `source <(carapace _carapace)` —
https://carapace-sh.github.io/carapace-bin/setup.html#oil

## 5. Carapace bridge

**YES — documented.** Verbatim official snippet (same as §1):

```sh
# ${UserConfigDir}/oil/oshrc
export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense' # optional
source <(carapace _carapace)
```

— https://carapace-sh.github.io/carapace-bin/setup.html#oil

## 6. Zoxide init

**No `zoxide init osh`/`ysh` command is documented.** The official getting-started page only notes:
*"See [OSH Compatibility Tips] to configure programs that rely on `eval` to initialize (e.g.
starship, zoxide)."* — https://www.oils.pub/release/latest/doc/getting-started.html#troubleshooting
The zoxide README offers a generic "Any POSIX shell" setup target but no Oil-specific line —
https://github.com/ajeetdsouza/zoxide#setup-zoxide-on-your-shell. → GAPS.

## 7. Self-completion (completion for the shell's OWN `completer` function)

**Feasible in principle** — `complete` "registers completion policies for different commands" and the
API is explicitly bash-compatible (sources in §2); bash `complete -F func completer` is the native
mechanism. **However, the official docs retrieved do not contain a verbatim `complete -F …` snippet,
nor any explicit statement about registering a completion for a shell function name.** The only
verbatim registration-adjacent snippet in official docs is the `compexport` example shown in §2 and
the sourced `_filedir()` example in the blog. No exact snippet can be supplied without speculation →
GAPS.

## Sources

1. https://www.oilshell.org/ (rename/move notice, 2025)
2. https://www.oils.pub/release/latest/doc/ (all docs index)
3. https://www.oils.pub/release/latest/doc/getting-started.html (rc paths, troubleshooting/zoxide)
4. https://www.oils.pub/release/latest/doc/completion.html (completion API overview)
5. https://raw.githubusercontent.com/oilshell/oil/master/doc/completion.md (source of #4)
6. https://www.oils.pub/release/latest/doc/ref/chap-builtin-cmd.html (complete/compgen/compopt/compadjust/compexport, alias/unalias, source)
7. https://www.oilshell.org/blog/2018/10/10.html (bash completion scripts under OSH; _filedir snippet)
8. https://carapace-sh.github.io/carapace-bin/setup.html#oil (Oil carapace bridge)
9. https://github.com/ajeetdsouza/zoxide#setup-zoxide-on-your-shell (no Oil target)

## GAPS

- Windows config path: none documented (docs are POSIX/XDG only).
- Config dir naming conflict: official docs say `~/.config/oils/oshrc`; carapace says
  `${UserConfigDir}/oil/oshrc`. Both are cited above; the discrepancy is unresolved by official docs.
- `complete` flag syntax for registering a function (e.g. `-F`) is not given verbatim in the official
  docs retrieved — no exact self-completion snippet.
- `compadjust` is explicitly a TODO in the official completion doc — undocumented details.
- Zoxide: no osh/ysh-specific init command documented; only a generic compatibility tip.
- Web search integration returned HTTP 402 during research; all findings came from direct fetches of
  the official URLs listed. Unbacked claims were deliberately omitted.

# Elvish — Official-Docs Research (INSPECTION-ONLY)

> **INSPECTION-ONLY**: Elvish is ABSENT on this host. No binary was inspected; all
> facts below come solely from official documentation (elv.sh, carapace-sh.github.io,
> github.com/ajeetdsouza/zoxide). No speculation.

## 1. Config / RC path

Source: https://elv.sh/ref/command.html#rc-file (section 2.1 "RC file").

The RC file path is determined as follows (verbatim from docs):
1. If the legacy `~/.elvish/rc.elv` exists, it is used (ignored starting from 0.21.0).
2. If `XDG_CONFIG_HOME` is defined and non-empty, `$XDG_CONFIG_HOME/elvish/rc.elv` is used.
3. Otherwise `~/.config/elvish/rc.elv` (non-Windows OSes) or `%AppData%\elvish\rc.elv` (Windows).

- Windows (documented): `%AppData%\elvish\rc.elv`. [https://elv.sh/ref/command.html#rc-file]
- POSIX (documented): `~/.config/elvish/rc.elv` (or `$XDG_CONFIG_HOME/elvish/rc.elv`). [https://elv.sh/ref/command.html#rc-file]
- Legacy fallback (both): `~/.elvish/rc.elv`. [https://elv.sh/ref/command.html#rc-file]
- If the RC file does not exist, Elvish executes no RC file. [https://elv.sh/ref/command.html#rc-file]
- Overrides: `-rc /path/to/rc` (testing an alternate RC), `-norc` (do not read RC). [https://elv.sh/ref/command.html#command-line-flags]
- Database file (not config): `~/.local/state/elvish/db.bolt` (non-Windows) / `%LocalAppData%\elvish\db.bolt` (Windows), or `$XDG_STATE_HOME/elvish/db.bolt`. [https://elv.sh/ref/command.html#database-file]

**Module search directories** (where sourced/generated `.elv` files live):
- `$XDG_CONFIG_HOME/elvish/lib`, else `~/.config/elvish/lib` (non-Windows) / `%RoamingAppData%\elvish\lib` (Windows).
- `$XDG_DATA_HOME/elvish/lib`, else `~/.local/share/elvish/lib` (non-Windows) / `%LocalAppData%\elvish\lib` (Windows).
- Legacy `~/.elvish/lib` (ignored from 0.21.0).
Source: https://elv.sh/ref/command.html#module-search-directories

Sibling-folder note (per project spec, researcher D owns placement): config dir is
`<XDG_CONFIG_HOME or ~/.config>/elvish` on POSIX and `%AppData%\elvish` on Windows.

## 2. Native completion API

Source: https://elv.sh/ref/edit.html#argument-completer (and `#edit:complex-candidate`).

Elvish command-argument completion is programmable via the `$edit:completion:arg-completer`
map. When completing an argument of command `$x`, Elvish calls the value stored in
`$edit:completion:arg-completer[$x]` with all existing arguments plus the command name in
front (e.g. `man 1<Tab>` -> `$edit:completion:arg-completer[man] man 1`;
new arg -> trailing empty string). [https://elv.sh/ref/edit.html#argument-completer]

Verbatim basic example (https://elv.sh/ref/edit.html#argument-completer):
```elvish
use re

var all-packages = [(apt-cache search '' | re:awk {|0 1 @rest| put $1 })]

set edit:completion:arg-completer[apt] = {|@args|
    var n = (count $args)
    if (== $n 2) {
        # apt x<Tab> -- complete a subcommand name
        put install uninstall
    } elif (== $n 3) {
        put $@all-packages
    }
}
```

Candidate emission options (verbatim facts from https://elv.sh/ref/edit.html#argument-completer):
- Byte output: `echo cand1; echo cand2` (one candidate per line; no newlines in candidates).
- Value output: `put cand1 cand2` (each string is a candidate).
- `edit:complex-candidate` for styled/described candidates.

Verbatim `edit:complex-candidate` snippet (https://elv.sh/ref/edit.html#argument-completer,
signature at https://elv.sh/ref/edit.html#edit:complex-candidate):
```elvish
edit:complex-candidate &code-suffix='' &display=$stem' ('$description')'  $stem
```
Signature: `edit:complex-candidate $stem &display='' &code-suffix=''`. The `&display` option
controls UI text; `&code-suffix` is appended when accepted. [https://elv.sh/ref/edit.html#edit:complex-candidate]

Other relevant APIs: `edit:complete-getopt $args $opt-specs $arg-handlers` and
`edit:complete-filename $args...`. [https://elv.sh/ref/edit.html#edit:complete-getopt,
https://elv.sh/ref/edit.html#edit:complete-filename]

Matcher: `$edit:completion:matcher` maps context -> matcher function; default prefix match.
[https://elv.sh/ref/edit.html#matcher]

## 3. Alias add / remove (native mechanism)

Elvish has NO `alias` builtin: the `builtin` module function list contains no `alias` command
(https://elv.sh/ref/builtin.html). Native equivalents:

- **Functions** define named commands: `fn ll {|@a| ls -l $@a }`.
  [https://elv.sh/ref/edit.html#edit:add-var]
- **Abbreviations** (Fish-like) are maps in `edit:`: `$edit:abbr`, `$edit:command-abbr`,
  `$edit:small-word-abbr`. Verbatim add snippets (https://elv.sh/ref/edit.html):
```elvish
set edit:abbr['||'] = '| less'
set edit:command-abbr['l'] = 'less'
set edit:command-abbr['gc'] = 'git commit'
set edit:small-word-abbr['gcm'] = 'git checkout master'
```
  (Sources: https://elv.sh/ref/edit.html#$edit:abbr,
  https://elv.sh/ref/edit.html#$edit:command-abbr,
  https://elv.sh/ref/edit.html#$edit:small-word-abbr)
- **REPL namespace** add/remove: `edit:add-var $name $init` / `edit:add-vars $map` add;
  `edit:del-var $name` / `edit:del-vars $list` delete. Verbatim:
```elvish
edit:add-var ll~ $ll~      # expose module function `util:ll` as `ll`
edit:del-var $name
```
  [https://elv.sh/ref/edit.html#edit:add-var, https://elv.sh/ref/edit.html#edit:del-var]

## 4. Sourcing generated files

- `use <module>` imports a module searched in the module search directories (§1).
  [https://elv.sh/ref/command.html#module-search-directories]
- `eval $code` evaluates a code *string*; `slurp` reads all input into a string. These compose
  to source generated code at runtime. [https://elv.sh/ref/builtin.html#eval,
  https://elv.sh/ref/builtin.html#slurp]
- Verbatim sourcing pattern (carapace, see §5): `eval (carapace _carapace|slurp)`.
  [https://carapace-sh.github.io/carapace-bin/setup.html#elvish]

## 5. Carapace bridge

Official carapace setup snippet for Elvish (verbatim,
https://carapace-sh.github.io/carapace-bin/setup.html#elvish):
```sh
# ${UserConfigDir}/elvish/rc.elv
set-env CARAPACE_BRIDGES 'zsh,fish,bash,inshellisense' # optional
eval (carapace _carapace|slurp)
```
The page notes `carapace _carapace` registers all available completers; a single completer
can be loaded by replacing `_carapace` with the completer name. [https://carapace-sh.github.io/carapace-bin/setup.html]

## 6. Zoxide init

Official zoxide README, Elvish section (verbatim,
https://github.com/ajeetdsouza/zoxide#setup-zoxide-on-your-shell):
```sh
eval (zoxide init elvish | slurp)
```
"Add this to the end of your config file (usually `~/.elvish/rc.elv`)." Note: zoxide only
supports elvish v0.18.0 and above. [https://github.com/ajeetdsouza/zoxide#setup-zoxide-on-your-shell]

## 7. Self-completion (completion for the shell's own `completer` function)

**Feasible: YES.** `$edit:completion:arg-completer` is keyed by the command name; registering
the key `completer` makes Elvish call that completer for the `completer` command just like any
other command. [https://elv.sh/ref/edit.html#argument-completer]

Exact snippet (assembled from the documented API pattern at
https://elv.sh/ref/edit.html#argument-completer — the docs carry no `completer`-specific
example, hence this is a direct application of the documented map assignment, not a quoted
passage):
```elvish
# completer = user function managing completions/aliases
fn completer {|@args| # ... body ...
}

set edit:completion:arg-completer[completer] = {|@args|
    var n = (count $args)
    if (== $n 2) {
        put add remove list update zoxide
    }
}
```
The callback receives `completer` as `$args[0]` plus the typed args, and emits candidates via
`put`/`echo`/`edit:complex-candidate`. [https://elv.sh/ref/edit.html#argument-completer]

## Sources
- https://elv.sh/ref/command.html (RC path, module dirs, flags, DB path)
- https://elv.sh/ref/edit.html (Completion API, `arg-completer`, `complex-candidate`, aliases/abbr maps, add/del-var)
- https://elv.sh/ref/builtin.html (no `alias` builtin; `eval`, `slurp`, function list)
- https://carapace-sh.github.io/carapace-bin/setup.html#elvish (carapace bridge)
- https://github.com/ajeetdsouza/zoxide (zoxide init elvish)

## GAPS
- The official docs give no `completer`-specific example; the self-completion snippet in §7 is
  assembled from the documented `arg-completer` map pattern, not quoted verbatim.
- No official doc explicitly states "Elvish has no alias command"; inferred factually from the
  absence of `alias` in the builtin function list and the presence of `fn`/abbreviation maps.
- Exact syntax for *deleting* a single `$edit:command-abbr` map key is not documented on the
  fetched pages (only `edit:del-var` for variables is documented); do not assume.
- RC-path "Windows + POSIX" for generated sibling folder is documented, but no
  `completer/` subfolder convention appears in official Elvish docs (project-specific).
- Host version absent; all APIs are INSPECTION-ONLY and unverified locally.

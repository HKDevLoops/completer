# Tcsh (csh) — Official-Docs Research

Status: **INSPECTION-ONLY**. `tcsh`/`csh` are absent on this host (verified with
`Get-Command tcsh,csh,ksh,ksh93,mksh -ErrorAction SilentlyContinue`, which returned
no results). Nothing below was executed or runtime-verified; all claims are from
official/man-page sources cited inline.

---

## Config / RC path(s)

The tcsh man page, "Startup and shutdown", states verbatim:

> "A login shell begins by executing commands from the system files /etc/csh.cshrc
> and /etc/csh.login. It then executes commands from files in the user's home
> directory: first ~/.tcshrc (+) or, if ~/.tcshrc is not found, ~/.cshrc, then
> ~/.history (or the value of the histfile shell variable), then ~/.login, and
> finally ~/.cshdirs (or the value of the dirsfile shell variable) (+)."
>
> "Non-login shells read only /etc/csh.cshrc and ~/.tcshrc or ~/.cshrc on startup."
>
> "The rest of this manual uses '~/.tcshrc' to mean '~/.tcshrc or, if ~/.tcshrc is
> not found, ~/.cshrc'."
>
> "When a login shell terminates it sets the logout shell variable to 'normal' or
> 'automatic' as appropriate, then executes commands from the files
> /etc/csh.logout and ~/.logout."

Source: https://linux.die.net/man/1/tcsh (Startup and shutdown)

**POSIX paths:** `~/.tcshrc` (primary), fallback `~/.cshrc`; `/etc/csh.cshrc`,
`/etc/csh.login`, `~/.login`, `~/.history`, `~/.cshdirs`, `~/.logout`,
`/etc/csh.logout`.

**Windows path:** No Windows-specific rc path is documented in either the tcsh
man page or the carapace setup page — both use the POSIX `~/.tcshrc` form only.
Source: https://linux.die.net/man/1/tcsh ; https://carapace-sh.github.io/carapace-bin/setup.html

---

## Native completion API

The `complete` builtin syntax, verbatim from the man page builtins section:

```
complete [command [word/pattern/list[:select]/[[suffix]/] ...]]
```

Source: https://linux.die.net/man/1/tcsh (builtin `complete`)

The man page's "Completion and listing" section states:

> "Finally, the complete builtin command can be used to tell the shell how to
> complete words other than filenames, commands and variables."
>
> "Remember that programmed completions are ignored if the word being completed
> is a tilde substitution (beginning with '~') or a variable (beginning with
> '$'). complete is an experimental feature, and the syntax may change in future
> versions of the shell. See also the uncomplete builtin command."

Source: https://linux.die.net/man/1/tcsh

Verbatim official examples:

```
> complete cd 'p/1/d/'
> complete alias 'p/1/a/'
> complete man 'p/*/c/'
> complete set 'p/1/s/'
> complete true 'p/1/x:Truth has no options./'
```

```
> complete find 'n/-user/u/'
```

```
> complete cc 'c/-I/d/'
```

```
> complete kill 'p/*/'ps | awk \{print\ \$1\}'/'
```

```
> complete ftp 'p/1/$hostnames/'
```

```
> complete elm c@=@F:$HOME/Mail/@
```

Source: https://linux.die.net/man/1/tcsh (builtin `complete` examples)

Documented completion-type characters (verbatim list from the man page):

```
c   Commands (builtin or external commands)
C   External commands which begin with the supplied path prefix
d   Directories
D   Directories which begin with the supplied path prefix
e   Environment variables
f   Filenames
F   Filenames which begin with the supplied path prefix
g   Groupnames
j   Jobs
l   Limits
n   Nothing
s   Shell variables
S   Signals
t   Plain ('text') files
T   Plain ('text') files which begin with the supplied path prefix
v   Any variables
u   Usernames
x   Like n, but prints select when list-choices is used.
X   Completions
$var    Words from the variable var
(...)   Words from the given list
'...'   Words from the output of command
```

Source: https://linux.die.net/man/1/tcsh (builtin `complete`, "Bindings (editor commands)")

The man page also documents command-generated completions with a `COMMAND_LINE`
environment variable:

> "command invoked from '...' version has additional environment variable set,
> the variable name is COMMAND_LINE and contains (as its name indicates)
> contents of the current (already typed in) command line."

Source: https://linux.die.net/man/1/tcsh

Removal / listing-related settings:

```
uncomplete pattern (+)
```

> "Removes all completions whose names match pattern. 'uncomplete *' thus removes
> all completions. It is not an error for nothing to be unaliased."

Source: https://linux.die.net/man/1/tcsh (builtin `uncomplete`)

```
> set autolist
```

> "If the autolist shell variable is set, the shell lists the remaining choices
> (if any) whenever completion fails"

Source: https://linux.die.net/man/1/tcsh (Completion and listing)

`bindkey` and `complete-word`:

> "The bindkey builtin can display and change key bindings."
> "complete-word (tab) — Completes a word as described under Completion and listing."

Source: https://linux.die.net/man/1/tcsh (The command-line editor; Editor commands)

---

## Alias add / remove (native mechanism)

Verbatim from the man page builtins section:

```
alias [name [wordlist]]
```

> "Without arguments, prints all aliases. With name, prints the alias for name.
> With name and wordlist, assigns wordlist as the alias of name. wordlist is
> command and filename substituted. name may not be 'alias' or 'unalias'."

```
unalias pattern
```

> "Removes all aliases whose names match pattern. 'unalias *' thus removes all
> aliases. It is not an error for nothing to be unaliased."

Source: https://linux.die.net/man/1/tcsh (builtins `alias`, `unalias`)

Concretely (derived directly from the documented grammar):

```
alias completer 'path/to/completer \!*'
unalias completer
```

---

## Sourcing generated files

Verbatim from the man page builtins section:

```
source [-h] name [args ...]
```

> "The shell reads and executes commands from name. The commands are not placed
> on the history list. If any args are given, they are placed in argv. (+) source
> commands may be nested; if they are nested too deeply the shell may run out of
> file descriptors. An error in a source at any level terminates all nested
> source commands. With -h, commands are placed on the history list instead of
> being executed, much like 'history -L'."

Source: https://linux.die.net/man/1/tcsh (builtin `source`)

Concretely (derived from documented grammar):

```
source ~/.tcshrc.d/completer/completer.tcsh
```

---

## Carapace bridge

Documented by carapace-sh, verbatim:

```
# ~/.tcshrc
setenv CARAPACE_BRIDGES 'zsh,fish,bash,inshellisense' # optional
set autolist
eval `carapace _carapace`
```

Source: https://carapace-sh.github.io/carapace-bin/setup.html (section "Tcsh")

The same page states globally:

> "This registers all the available completers. It is also possible to load a
> single one by replacing _carapace with the completer name (e.g. carapace chmod)."

Source: https://carapace-sh.github.io/carapace-bin/setup.html

---

## Zoxide init

Documented by the official zoxide project README, verbatim:

```
# ~/.tcshrc
zoxide init tcsh > ~/.zoxide.tcsh
source ~/.zoxide.tcsh
```

> "Add this to the end of your config file (usually ~/.tcshrc):"

Source: https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/README.md (section "Tcsh", "Setup zoxide on your shell")

---

## Self-completion (completion for its OWN `completer` function)

**Feasible: YES.** The documented `complete` grammar accepts an arbitrary command
word (`complete [command [...]]`), and the man page demonstrates registering
completions for shell builtins such as `alias`, `man`, `set` and `true`. The
`( ... )` list form ("Words from the given list") is documented, so a completion
for a function/command named `completer` can be registered directly.

Exact snippet (constructed from the documented `complete` grammar; the official
docs contain no literal `completer` example):

```
complete completer 'p/1/(add remove list update)/'
```

First-argument-as-alias variant, using the documented `a` type and the verbatim
`complete alias 'p/1/a/'` pattern from the man page:

```
complete completer 'p/1/a/'
```

Removal (documented `uncomplete` builtin):

```
uncomplete completer
```

Sources: https://linux.die.net/man/1/tcsh (builtins `complete`, `uncomplete`);
https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/README.md

---

## GAPS

1. No Windows-specific rc path for tcsh is documented in the fetched official
   sources; only POSIX `~/.tcshrc` / `~/.cshrc` are documented.
2. The official docs contain no literal `completer` self-completion example; the
   snippets above are derived from the documented `complete` grammar, not copied
   verbatim from a doc example.
3. `complete` is explicitly labelled experimental by the man page ("the syntax
   may change in future versions of the shell").
4. Both `tcsh` and `csh` are absent on this host — INSPECTION-ONLY, no runtime
   verification of any snippet was possible.
5. The canonical upstream tcsh project site was not separately retrieved; the
   cited man page is a distro-hosted mirror explicitly supplied as a starting
   URL in the task.
6. The carapace `eval \`carapace _carapace\`` output for tcsh was not runtime-tested
   (binary absent), only its setup snippet was verified from the official site.

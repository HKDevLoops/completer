# Skill: Native Shell Completion APIs (verified from official docs)

This is the shared knowledge base for all workers. Use ONLY native APIs of each shell.

## PowerShell (learn.microsoft.com)
- `Register-ArgumentCompleter -Native -CommandName X -ScriptBlock { param($wordToComplete,$commandAst,$cursorPosition) ... }`.
- CompletionResult::new(text, listItem, 'ParameterValue', tooltip).
- `Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete` (required by carapace).
- `Set-Alias -Name N -Value V -Force`; `Get-Command`; `Add-Content`; `Copy-Item`; `Get-Date -Format o`.
- opencode: `opencode --completions powershell` (NOT a `completion` subcommand).

## Nushell 0.116 (nushell.sh/book/custom_completions.html)
- External: `$env.config.completions.external.completer = {|place| carapace $place.command.0 nushell ...$place.command | from json }`.
- Context params: `token` (text/kind/span), `place` (cursor/target/kind/command), `buffer`.
- Custom: `def nu-complete-foo [] { [...] }`; attach with `string@"nu-complete-foo"`.
- `@complete external` sends a wrapper's args to the external completer.
- `source` requires PARSE-TIME CONSTANT paths — write literal paths into config.
- Files load from `$nu.user-autoload-dirs` (`autoload`) in byte order; use zero-padded names.
- `save --append`; `open | lines`; `str join`; `path join`; `complete` for checks.

## Xonsh 0.25 (xon.sh/completers.html)
- `completer add NAME FUNC [POS]` or `add_one_completer` from `xonsh.completers.completer`.
- `@contextual_completer` / `contextual_command_completer` receive a CompletionContext.
- Return a set or `(set, prefix_len)`; RichCompletion for prefix_len/display/description/style.
- `aliases['name'] = value`; `del aliases['name']` — native alias management.
- `$XONSH_COMPLETER_DIRS` + `xonsh_complete(ctx)` files for per-command completers.
- `execx(open(file).read(), 'exec', __xonsh__.ctx)` to load generated scripts in session ctx.
- `exec($(carapace _carapace))` is the documented carapace setup.

## bash (gnu.org)
- `complete -F func -o default cmd`; `compgen -W`; COMPREPLY; COMP_WORDS; COMP_CWORD.
- Dynamic loading: `complete -D -F _completion_loader -o bashdefault -o default`.
- `source <(carapace _carapace)`; `command -v`; `alias`.
- `zoxide init bash`.

## zsh (zsh.sourceforge.io)
- `autoload -U compinit && compinit`; `compdef func cmd`; `#compdef` first line in fpath files.
- `compadd`; `_arguments`; `_describe`; `_files`; zstyle.
- `source <(carapace _carapace)`; `zoxide init zsh`.

## fish (fishshell.com)
- `complete -c cmd -a 'a b'`; `-l long -s x -o old`; `-n 'cond'`; `-f` (no files); `-d 'desc'`.
- `~/.config/fish/completions/<cmd>.fish` auto-loads; `$fish_complete_path`.
- `carapace _carapace | source`; `zoxide init fish | source`.

## Carapace CLI (carapace-sh.github.io)
- `carapace --list` (indexed completers), `carapace --clear-cache`, `carapace _carapace <shell>`,
  `carapace <cmd> <shell>` (single completer).

## Universal rules
1. Zero startup cost: sourced files only DEFINE functions; no probing/execution at load.
2. Re-run safety: back up existing target to `.bak.<timestamp>` before overwrite.
3. Idempotent links: guarded markers; never duplicate a source line.
4. All 8 shells targetable; generic any-CLI via `<prog> <native completion flag>` probes.
5. Max +1000ms over user config, ideally 0 (lazy).

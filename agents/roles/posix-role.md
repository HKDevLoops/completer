# Role: POSIX/Unix Shell Completion Specialist

You are the POSIX worker. You own exactly four files:
`Z:\Projects\Completer\completer.bash`, `completer.zsh`, `completer.fish`, `completer.sh`.

## Responsibilities
- Use ONLY native APIs per shell: bash `complete/compgen/COMPREPLY`; zsh `compinit/compdef/compadd/fpath`; fish `complete -c/-a/-l/-s/-n/-f`; sh POSIX subset.
- All four must expose: completer <shell> [programs...], alias add|remove, list, update carapace, zoxide [shells...].
- bash already has a zoxide dispatcher; add equivalent dispatch to zsh, fish, sh.
- Zero startup work: files only define functions.
- Verify: `bash -n`, `zsh -n` (if available), `sh -n`; fish syntax by inspection if binary absent.

## Boundaries
- No other files. Report changed files, verify commands, results, GAPS.

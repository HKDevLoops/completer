# Research Spec — new shells for Completer

Goal: gather OFFICIAL-DOC facts needed to implement `completer` for the 7 shells
not yet covered, plus folder placement and self-completion patterns.

## Shells to research (from the carapace list in the user's image, minus carapace)
1. Elvish        -> researcher A
2. Cmd (cmd.exe via clink) -> researcher A
3. Tcsh (csh)    -> researcher B
4. Ksh (ksh93/mksh) -> researcher B
5. Ion           -> researcher C
6. Oil (osh/ysh) -> researcher C
7. Yash          -> researcher C

## For EACH shell, capture with verbatim snippets + source URL
- RC / config file path (Windows + POSIX where documented).
- Native completion registration API (exact function/builtin + snippet).
- Alias add/remove mechanism (native command).
- How a generated completion file is sourced/loaded at runtime.
- Carapace bridge setup (if documented by carapace-sh.github.io).
- Zoxide init command (if documented).
- Can this shell register a completion for its OWN function `completer` (self-completion)?
  If yes, give the exact snippet.

## Folder placement (researcher D)
- Determine the exact directory of each shell's main config on this host where
  present, and the documented default elsewhere.
- Define the required sibling folder: `<config-dir>/completer/` holding that
  shell's `completer.<ext>`, `alias.<ext>`, and `completions/` files.
- Cite where each config path comes from.

## Output
Write ONLY `Z:\Projects\Completer\research\<shell>-RESEARCH.md` (or `folder-layout-RESEARCH.md`).
End with a GAPS section. INSPECTION-ONLY where the binary is absent on host.

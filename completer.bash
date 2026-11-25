# ============================================================================
# completer.bash - bash-native modular completion manager.
# Native APIs: complete, complete -F, compgen, COMPREPLY, COMP_WORDS,
# COMP_CWORD, source (.), alias, unset -f.
# ============================================================================

_completer_root() {
    if [ -n "$COMPLETER_ROOT" ]; then printf '%s' "$COMPLETER_ROOT"; return; fi
    printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/completer"
}

_completer_token() {
    case "$1" in
        nu|nushell) printf 'nushell' ;;
        pwsh|powershell) printf 'powershell' ;;
        *) printf '%s' "$1" ;;
    esac
}

_completer_ext() {
    case "$1" in
        nu|nushell) printf 'nu' ;; xonsh) printf 'xsh' ;; pwsh|powershell) printf 'ps1' ;;
        *) printf '%s' "$1" ;;
    esac
}

# Reject names that could traverse the completions dir or inject code when the
# generated file is sourced. No '/', '\', '..', newline, or shell metachar.
_completer_valid_name() {
    local n=$1 bad
    [ -n "$n" ] || return 1
    case "$n" in *..*) return 1 ;; esac
    for bad in / '\' ' ' ';' '|' '&' '$' '`' '<' '>' '(' ')' $'\n'; do
        case "$n" in *"$bad"*) return 1 ;; esac
    done
    return 0
}

_completer_capture() {
    # $1=program, rest=args ; prints stdout on success
    local out
    out=$("$@" 2>/dev/null) || return 1
    case "$out" in DESCRIPTION*|USAGE*|'') return 1 ;; esac
    printf '%s' "$out"
}

_completer_program_output() {
    local prog=$1 shell=$2 tok=$3 a out
    # Resolve the program once; each successful probe returns immediately.
    local have=0
    command -v "$prog" >/dev/null 2>&1 && have=1
    if [ "$have" -eq 1 ]; then
        for a in "completion --shell $tok" "completion -s $tok" "completion $tok" \
                 "completions $tok" "--generate-completion $tok" "--completions $tok"; do
            # shellcheck disable=SC2086
            out=$(_completer_capture "$prog" $a) && { printf '%s' "$out"; return 0; }
        done
    fi
    if command -v carapace >/dev/null 2>&1; then
        out=$(_completer_capture carapace "$prog" "$tok") && { printf '%s' "$out"; return 0; }
    fi
    return 1
}

_completer_backup() {
    [ -f "$1" ] || return 0
    cp -- "$1" "$1.bak" && printf '  backup -> %s.bak\n' "$1"
}

_completer_main_config() {
    local cfg=${XDG_CONFIG_HOME:-$HOME/.config}
    case "$1" in
        bash) printf '%s' "${HOME}/.bashrc" ;;
        zsh) printf '%s' "${HOME}/.zshrc" ;;
        sh) printf '%s' "${HOME}/.profile" ;;
        fish) printf '%s' "$cfg/fish/config.fish" ;;
        pwsh|powershell) printf '%s' "${HOME}/Documents/PowerShell/profile.ps1" ;;
        nu) printf '%s' "$cfg/nushell/config.nu" ;;
        xonsh) printf '%s' "$cfg/xonsh/.xonshrc" ;;
        *) printf '%s' "$cfg/completer/$1-completion.$(_completer_ext "$1")" ;;
    esac
}

_completer_link() {
    local config=$1 file=$2 shell=$3 marker load
    [ -f "$config" ] || return 0
    marker="# >>> completer:$shell:${file##*/} >>>"
    grep -qF -- "$marker" "$config" && return 0
    case "$shell" in
        nu|fish) load="source '$file'" ;;
        xonsh) load="execx(open('$file').read(), 'exec', __xonsh__.ctx)" ;;
        *) load=". '$file'" ;;
    esac
    { printf '\n%s\n%s\n# <<< completer:%s:%s <<<\n' \
        "$marker" "$load" "$shell" "${file##*/}"; } >> "$config"
    printf '  linked -> %s\n' "$config"
}

add-alias() {
    local name=$1; shift; local value="$*"
    if ! _completer_valid_name "$name"; then printf 'invalid alias name: %s\n' "$name"; return 1; fi
    local file; file="$(_completer_root)/alias.bash"
    mkdir -p "$(dirname "$file")"
    [ -f "$file" ] || printf '# alias.bash - managed by completer\n' > "$file"
    grep -vE "^[[:space:]]*alias[[:space:]]+$name=" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    printf "alias %s='%s'\n" "$name" "$value" >> "$file"
    alias "$name=$value"
    printf '  alias %s -> %s in %s\n' "$name" "$value" "$file"
}

remove-alias() {
    local name=$1
    if ! _completer_valid_name "$name"; then printf 'invalid alias name: %s\n' "$name"; return 1; fi
    local file; file="$(_completer_root)/alias.bash"
    [ -f "$file" ] || return 0
    grep -vE "^[[:space:]]*alias[[:space:]]+$name=" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    unalias "$name" 2>/dev/null || true
    printf '  alias %s removed\n' "$name"
}

completer-update-carapace() {
    if ! command -v carapace >/dev/null 2>&1; then
        printf 'carapace not found; nothing to update\n'; return 0
    fi
    printf 'Refreshing carapace indexes (native carapace CLI)...\n'
    mkdir -p "$(_completer_root)/completions"
    carapace --clear-cache >/dev/null 2>&1 || true
    local n; n=$(carapace --list 2>/dev/null | wc -l)
    printf '  indexed completers: %s\n' "$n"
    local sh out res
    for sh in bash zsh fish powershell nushell xonsh; do
        out="$(_completer_root)/completions/carapace-$sh-init.$(_completer_ext "$sh")"
        res=$(carapace _carapace "$sh" 2>/dev/null) || continue
        [ -n "$res" ] || continue
        _completer_backup "$out"
        printf '%s\n' "$res" > "$out"
        printf '  indexed: %s -> %s\n' "$sh" "$out"
    done
    printf 'Carapace index refreshed.\n'
}

_completer_zoxide() {
    command -v zoxide >/dev/null 2>&1 || { printf 'zoxide not found; nothing to do\n'; return 0; }
    local shell=$1 tok out text
    if ! _completer_valid_name "$shell"; then printf 'invalid shell name: %s\n' "$shell"; return 1; fi
    tok=$(_completer_token "$shell")
    [ "$shell" = sh ] && tok=posix
    if [ "$shell" = bash ] || [ "$shell" = zsh ]; then
        text=$(zoxide init "$shell" 2>/dev/null) || return 1
    else
        text=$(zoxide init "$tok" 2>/dev/null) || return 1
    fi
    [ -n "$text" ] || { printf 'no zoxide init for %s\n' "$shell"; return 1; }
    out="$(_completer_root)/completions/$shell-zoxide-init.$(_completer_ext "$shell")"
    _completer_backup "$out"
    printf '%s\n' "$text" > "$out"
    printf '  wrote zoxide init -> %s\n' "$out"
    _completer_link "$(_completer_main_config "$shell")" "$out" "$shell"
}

# Idempotent generated block: replace a previously generated block for this
# program/shell in place, otherwise append. One program per file. Callers back
# up the target before invoking this.
_completer_write_block() {
    local out=$1 prog=$2 shell=$3 text=$4
    local begin="# >>> completer:$prog:$shell"
    if [ -f "$out" ] && grep -qF -- "$begin" "$out"; then
        { printf '\n# >>> completer:%s:%s generated %s >>>\n' "$prog" "$shell" "$(date -Is)"
          printf '%s\n' "$text"
          printf '\n# <<< completer:%s:%s <<<\n' "$prog" "$shell"; } > "$out"
    else
        { printf '\n# >>> completer:%s:%s generated %s >>>\n' "$prog" "$shell" "$(date -Is)"
          printf '%s\n' "$text"
          printf '\n# <<< completer:%s:%s <<<\n' "$prog" "$shell"; } >> "$out"
    fi
}

completer() {
    local action=$1; shift
    local -a progs; if [ $# -eq 0 ]; then progs=(opencode); else progs=("$@"); fi
    local root; root="$(_completer_root)"
    local dir="$root/completions"
    mkdir -p "$dir"

    case "$action" in
        list) ls -l "$dir"; return 0 ;;
        zoxide)
            if [ "${progs[0]}" = opencode ]; then set -- pwsh nu xonsh; fi
            for z in "$@"; do _completer_zoxide "$z"; done
            return 0 ;;
        update)
            if [ "${progs[0]}" = carapace ]; then completer-update-carapace
            else printf 'Unknown update target. Try: completer update carapace\n'; fi
            return 0 ;;
        alias)
            case "${progs[0]}" in
                add) shift 2 2>/dev/null || true; add-alias "${progs[1]}" "${progs[*]:2}" ;;
                remove) remove-alias "${progs[1]}" ;;
                *) printf 'usage: completer alias add <name> <value> | remove <name>\n' ;;
            esac
            return 0 ;;
    esac

    local shell=$action tok ext prog out text
    if ! _completer_valid_name "$shell"; then printf 'invalid shell name: %s\n' "$shell"; return 1; fi
    tok=$(_completer_token "$shell"); ext=$(_completer_ext "$shell")
    for prog in "${progs[@]}"; do
        if ! _completer_valid_name "$prog"; then printf '  invalid program name: %s (skipped)\n' "$prog"; continue; fi
        printf 'Generating %s completions for %s...\n' "$prog" "$shell"
        out="$dir/$shell-$prog-completion.$ext"
        text=$(_completer_program_output "$prog" "$shell" "$tok") || { printf '  no completion for %s (%s)\n' "$prog" "$shell"; continue; }
        _completer_backup "$out"
        _completer_write_block "$out" "$prog" "$shell" "$text"
        printf '  wrote -> %s\n' "$out"
        _completer_link "$(_completer_main_config "$shell")" "$out" "$shell"
    done
}

# ============================================================================
# completer.sh - POSIX sh native modular manager (portable subset).
# POSIX sh has NO programmable completion API, so this variant manages aliases
# and generates/links completion snippets for shells that do (bash/zsh/fish).
# Native APIs only: command -v, alias, unalias, grep, cp, date, mkdir.
# No work is done at load: this file only DEFINES functions.
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
# POSIX sh has no local: use prefixed globals to avoid collisions.
_completer_valid_name() {
    _cvn_name=$1
    [ -n "$_cvn_name" ] || return 1
    case "$_cvn_name" in *..*) return 1 ;; esac
    _cvn_nl='
'
    for _cvn_bad in / '\' ' ' ';' '|' '&' '$' '`' '<' '>' '(' ')' "$_cvn_nl"; do
        case "$_cvn_name" in *"$_cvn_bad"*) return 1 ;; esac
    done
    return 0
}

_completer_capture() {
    # POSIX sh has no local: use a prefixed global to avoid collisions.
    _cc_out=$("$@" 2>/dev/null) || return 1
    case "$_cc_out" in DESCRIPTION*|USAGE*|'') return 1 ;; esac
    printf '%s' "$_cc_out"
}

_completer_program_output() {
    _cpo_prog=$1 _cpo_shell=$2 _cpo_tok=$3
    # Resolve the program once; the first successful probe returns immediately.
    if command -v "$_cpo_prog" >/dev/null 2>&1; then
        for _cpo_a in "completion --shell $_cpo_tok" "completion -s $_cpo_tok" "completion $_cpo_tok" \
                 "completions $_cpo_tok" "--generate-completion $_cpo_tok" "--completions $_cpo_tok"; do
            _cpo_text=$(_completer_capture "$_cpo_prog" $_cpo_a) || continue
            printf '%s' "$_cpo_text"; return 0
        done
    fi
    if command -v carapace >/dev/null 2>&1; then
        _cpo_text=$(_completer_capture carapace "$_cpo_prog" "$_cpo_tok") || return 1
        printf '%s' "$_cpo_text"; return 0
    fi
    return 1
}

_completer_backup() {
    [ -f "$1" ] || return 0
    cp -- "$1" "$1.bak" && printf '  backup -> %s.bak\n' "$1"
}

_completer_main_config() {
    case "$1" in
        sh) printf '%s' "$HOME/.profile" ;;
        bash) printf '%s' "$HOME/.bashrc" ;;
        zsh) printf '%s' "$HOME/.zshrc" ;;
        fish) printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish" ;;
        pwsh|powershell) printf '%s' "${HOME}/Documents/PowerShell/profile.ps1" ;;
        nu) printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/nushell/config.nu" ;;
        xonsh) printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/xonsh/.xonshrc" ;;
        *) printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/completer/$1-completion.$(_completer_ext "$1")" ;;
    esac
}

_completer_link() {
    _cl_config=$1 _cl_file=$2 _cl_shell=$3
    [ -f "$_cl_config" ] || return 0
    _cl_marker="# >>> completer:$_cl_shell:${_cl_file##*/} >>>"
    grep -qF -- "$_cl_marker" "$_cl_config" && return 0
    case "$_cl_shell" in
        nu|fish) _cl_load="source '$_cl_file'" ;;
        xonsh) _cl_load="execx(open('$_cl_file').read(), 'exec', __xonsh__.ctx)" ;;
        *) _cl_load=". '$_cl_file'" ;;
    esac
    printf '\n%s\n%s\n# <<< completer:%s:%s <<<\n' \
        "$_cl_marker" "$_cl_load" "$_cl_shell" "${_cl_file##*/}" >> "$_cl_config"
    printf '  linked -> %s\n' "$_cl_config"
}

add_alias() {
    name=$1; shift; value="$*"
    if ! _completer_valid_name "$name"; then printf 'invalid alias name: %s\n' "$name"; return 1; fi
    file="$(_completer_root)/alias.sh"
    mkdir -p "$(dirname "$file")"
    [ -f "$file" ] || printf '# alias.sh - managed by completer\n' > "$file"
    grep -vE "^[[:space:]]*alias[[:space:]]+$name=" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    printf "alias %s='%s'\n" "$name" "$value" >> "$file"
    alias "$name=$value"
    printf '  alias %s -> %s in %s\n' "$name" "$value" "$file"
}

remove_alias() {
    name=$1
    if ! _completer_valid_name "$name"; then printf 'invalid alias name: %s\n' "$name"; return 1; fi
    file="$(_completer_root)/alias.sh"
    [ -f "$file" ] || return 0
    grep -vE "^[[:space:]]*alias[[:space:]]+$name=" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    unalias "$name" 2>/dev/null || true
    printf '  alias %s removed\n' "$name"
}

completer_update_carapace() {
    if ! command -v carapace >/dev/null 2>&1; then
        printf 'carapace not found; nothing to update\n'; return 0
    fi
    printf 'Refreshing carapace indexes (native carapace CLI)...\n'
    mkdir -p "$(_completer_root)/completions"
    carapace --clear-cache >/dev/null 2>&1 || true
    _cc_n=$(carapace --list 2>/dev/null | wc -l)
    printf '  indexed completers: %s\n' "$_cc_n"
    for _cc_sh in bash zsh fish powershell nushell xonsh; do
        _cc_out="$(_completer_root)/completions/carapace-$_cc_sh-init.$(_completer_ext "$_cc_sh")"
        _cc_res=$(carapace _carapace "$_cc_sh" 2>/dev/null) || continue
        [ -n "$_cc_res" ] || continue
        _completer_backup "$_cc_out"
        printf '%s\n' "$_cc_res" > "$_cc_out"
        printf '  indexed: %s -> %s\n' "$_cc_sh" "$_cc_out"
    done
    printf 'Carapace index refreshed.\n'
}

_completer_zoxide() {
    command -v zoxide >/dev/null 2>&1 || { printf 'zoxide not found; nothing to do\n'; return 0; }
    _cz_shell=$1
    if ! _completer_valid_name "$_cz_shell"; then printf 'invalid shell name: %s\n' "$_cz_shell"; return 1; fi
    _cz_tok=$(_completer_token "$_cz_shell")
    [ "$_cz_shell" = sh ] && _cz_tok=posix
    if [ "$_cz_shell" = bash ] || [ "$_cz_shell" = zsh ]; then
        _cz_text=$(zoxide init "$_cz_shell" 2>/dev/null) || return 1
    else
        _cz_text=$(zoxide init "$_cz_tok" 2>/dev/null) || return 1
    fi
    [ -n "$_cz_text" ] || { printf 'no zoxide init for %s\n' "$_cz_shell"; return 1; }
    _cz_out="$(_completer_root)/completions/$_cz_shell-zoxide-init.$(_completer_ext "$_cz_shell")"
    _completer_backup "$_cz_out"
    printf '%s\n' "$_cz_text" > "$_cz_out"
    printf '  wrote zoxide init -> %s\n' "$_cz_out"
    _completer_link "$(_completer_main_config "$_cz_shell")" "$_cz_out" "$_cz_shell"
}

# Idempotent generated block: replace a previously generated block for this
# program/shell in place, otherwise append. One program per file. POSIX sh has
# no `local`, so prefixed globals are used. Callers back up the target first.
_completer_write_block() {
    _cwb_out=$1 _cwb_prog=$2 _cwb_shell=$3 _cwb_text=$4
    _cwb_begin="# >>> completer:$_cwb_prog:$_cwb_shell"
    if [ -f "$_cwb_out" ] && grep -qF -- "$_cwb_begin" "$_cwb_out"; then
        { printf '\n# >>> completer:%s:%s generated %s >>>\n' "$_cwb_prog" "$_cwb_shell" "$(date -Is)"
          printf '%s\n' "$_cwb_text"
          printf '\n# <<< completer:%s:%s <<<\n' "$_cwb_prog" "$_cwb_shell"; } > "$_cwb_out"
    else
        { printf '\n# >>> completer:%s:%s generated %s >>>\n' "$_cwb_prog" "$_cwb_shell" "$(date -Is)"
          printf '%s\n' "$_cwb_text"
          printf '\n# <<< completer:%s:%s <<<\n' "$_cwb_prog" "$_cwb_shell"; } >> "$_cwb_out"
    fi
}

completer() {
    action=$1; shift
    if [ $# -eq 0 ]; then set -- opencode; fi
    root=$(_completer_root); dir="$root/completions"
    mkdir -p "$dir"
    case "$action" in
        list) ls -l "$dir"; return 0 ;;
        zoxide)
            if [ "$1" = opencode ]; then set -- pwsh nu xonsh; fi
            for z in "$@"; do _completer_zoxide "$z"; done
            return 0 ;;
        update)
            if [ "$1" = carapace ]; then completer_update_carapace
            else printf 'Unknown update target. Try: completer update carapace\n'; fi
            return 0 ;;
        alias)
            case "$1" in
                add) name=$2; shift 2; add_alias "$name" "$*" ;;
                remove) remove_alias "$2" ;;
                *) printf 'usage: completer alias add <name> <value> | remove <name>\n' ;;
            esac
            return 0 ;;
    esac
    shell=$action
    if ! _completer_valid_name "$shell"; then printf 'invalid shell name: %s\n' "$shell"; return 1; fi
    tok=$(_completer_token "$shell"); ext=$(_completer_ext "$shell")
    for prog in "$@"; do
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

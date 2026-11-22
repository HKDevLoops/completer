# ============================================================================
# completer.ksh - KornShell (ksh93 / mksh) native modular completion manager.
#
# ZERO STARTUP WORK: sourcing this file only DEFINES functions. No probing,
# no config writes happen at load time.
#
# Native APIs used (official docs below):
#   name() { ... } / alias / unalias / . (dot) / typeset / command -v
#   ksh93: KEYBD trap + .sh.edtext (generic command completion covers functions)
#   mksh:  set -A complete_completer_1 -- ... (pdksh-family complete_* arrays)
#   carapace CLI: --clear-cache / --list / _carapace <shell>  (no ksh bridge exists)
#   zoxide: generic `zoxide init posix --hook prompt` (no ksh target exists)
#
# Official docs:
#   https://linux.die.net/man/1/ksh93
#   https://raw.githubusercontent.com/ksh93/ksh/master/src/cmd/ksh93/sh.1
#   https://raw.githubusercontent.com/MirBSD/mksh/master/mksh.1
#   https://man.openbsd.org/ksh.1
#   https://carapace-sh.github.io/carapace-bin/setup.html   (no Ksh section)
#   https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/README.md
#
# GAPs vs the universal surface:
#   - ksh93 has NO documented per-command completion API (only built-in completion
#     + generic KEYBD trap); a `completer` FUNCTION is covered by generic command
#     completion, but a dedicated argument-completer cannot be registered.
#   - mksh `complete_*` arrays are documented by the OpenBSD ksh man page only
#     (attribution caveat); used here for best-effort self-completion.
#   - No carapace bridge and no ksh zoxide init are documented; native CLIs are
#     still run into files, but there is no bridge to source for ksh itself.
# ============================================================================

_completer_root() {
    typeset cfg
    if [ -n "$COMPLETER_ROOT" ]; then printf '%s' "$COMPLETER_ROOT"; return; fi
    cfg=${XDG_CONFIG_HOME:-$HOME/.config}
    printf '%s' "$cfg/completer"
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
        nu) printf 'nu' ;; xonsh) printf 'xsh' ;; pwsh) printf 'ps1' ;;
        *) printf '%s' "$1" ;;
    esac
}

_completer_capture() {
    _cc_out=$("$@" 2>/dev/null) || return 1
    case "$_cc_out" in DESCRIPTION*|USAGE*|'') return 1 ;; esac
    printf '%s' "$_cc_out"
}

_completer_program_output() {
    _cpo_prog=$1 _cpo_shell=$2 _cpo_tok=$3
    for _cpo_a in "completion --shell $_cpo_tok" "completion -s $_cpo_tok" "completion $_cpo_tok" \
                  "completions $_cpo_tok" "--generate-completion $_cpo_tok" "--completions $_cpo_tok"; do
        command -v "$_cpo_prog" >/dev/null 2>&1 || continue
        _cpo_text=$(_completer_capture "$_cpo_prog" $_cpo_a) || continue
        printf '%s' "$_cpo_text"; return 0
    done
    if command -v carapace >/dev/null 2>&1; then
        _cpo_text=$(_completer_capture carapace "$_cpo_prog" "$_cpo_tok") || return 1
        printf '%s' "$_cpo_text"; return 0
    fi
    return 1
}

_completer_backup() {
    [ -f "$1" ] || return 0
    _cb_stamp=$(date +%Y%m%d-%H%M%S)
    cp -- "$1" "$1.bak.$_cb_stamp" && printf '  backup -> %s.bak.%s\n' "$1" "$_cb_stamp"
}

_completer_main_config() {
    typeset cfg=${XDG_CONFIG_HOME:-$HOME/.config}
    case "$1" in
        sh) printf '%s' "$HOME/.profile" ;;
        bash) printf '%s' "$HOME/.bashrc" ;;
        zsh) printf '%s' "$HOME/.zshrc" ;;
        ksh) printf '%s' "${ENV:-$HOME/.kshrc}" ;;
        fish) printf '%s' "$cfg/fish/config.fish" ;;
        pwsh|powershell) printf '%s' "${HOME}/Documents/PowerShell/profile.ps1" ;;
        nu) printf '%s' "$cfg/nushell/config.nu" ;;
        xonsh) printf '%s' "$cfg/xonsh/.xonshrc" ;;
        *) printf '%s' "$cfg/completer/$1-completion.$(_completer_ext "$1")" ;;
    esac
}

_completer_link() {
    _cl_config=$1 _cl_file=$2 _cl_shell=$3
    [ -f "$_cl_config" ] || return 0
    _cl_base=${_cl_file##*/}
    _cl_marker="# >>> completer:$_cl_shell:$_cl_base >>>"
    grep -qF -- "$_cl_marker" "$_cl_config" && return 0
    case "$_cl_shell" in
        nu|fish) _cl_load="source '$_cl_file'" ;;
        xonsh) _cl_load="execx(open('$_cl_file').read(), 'exec', __xonsh__.ctx)" ;;
        *) _cl_load=". '$_cl_file'" ;;
    esac
    printf '\n%s\n%s\n# <<< completer:%s:%s <<<\n' \
        "$_cl_marker" "$_cl_load" "$_cl_shell" "$_cl_base" >> "$_cl_config"
    printf '  linked -> %s\n' "$_cl_config"
}

_add_alias() {
    _ca_name=$1; shift; _ca_value="$*"
    _ca_file="$(_completer_root)/alias.ksh"
    mkdir -p "$(dirname "$_ca_file")"
    [ -f "$_ca_file" ] || printf '# alias.ksh - managed by completer\n' > "$_ca_file"
    grep -vE "^[[:space:]]*alias[[:space:]]+$_ca_name=" "$_ca_file" > "$_ca_file.tmp" && mv "$_ca_file.tmp" "$_ca_file"
    printf "alias %s='%s'\n" "$_ca_name" "$_ca_value" >> "$_ca_file"
    alias "$_ca_name=$_ca_value"
    printf '  alias %s -> %s in %s\n' "$_ca_name" "$_ca_value" "$_ca_file"
}

_remove_alias() {
    _cr_name=$1
    _cr_file="$(_completer_root)/alias.ksh"
    [ -f "$_cr_file" ] || return 0
    grep -vE "^[[:space:]]*alias[[:space:]]+$_cr_name=" "$_cr_file" > "$_cr_file.tmp" && mv "$_cr_file.tmp" "$_cr_file"
    unalias "$_cr_name" 2>/dev/null || true
    printf '  alias %s removed\n' "$_cr_name"
}

# Best-effort self-completion. mksh: complete_* array; ksh93: no API (generic only).
_completer_register_self() {
    case "${KSH_VERSION:-}" in
        *MIRB*|*MirBSD*|*pdksh*)
            set -A complete_completer_1 -- add remove list update zoxide self
            set -A complete_completer -- add remove list update zoxide self
            printf 'Self-completion registered via mksh complete_* arrays.\n' ;;
        *)
            printf 'ksh93: no per-command completion API; function "completer" is covered by generic command completion.\n' ;;
    esac
}

_completer_update_carapace() {
    if ! command -v carapace >/dev/null 2>&1; then
        printf 'carapace not found; nothing to update\n'; return 0
    fi
    printf 'Refreshing carapace indexes (native carapace CLI)...\n'
    mkdir -p "$(_completer_root)/completions"
    carapace --clear-cache >/dev/null 2>&1 || true
    _cc_n=$(carapace --list 2>/dev/null | wc -l)
    printf '  indexed completers: %s\n' "$_cc_n"
    _cc_dir="$(_completer_root)/completions"
    for _cc_sh in bash zsh fish powershell nushell xonsh; do
        _cc_out="$_cc_dir/carapace-$_cc_sh-init.$(_completer_ext "$_cc_sh")"
        _cc_res=$(carapace _carapace "$_cc_sh" 2>/dev/null) || continue
        [ -n "$_cc_res" ] || continue
        _completer_backup "$_cc_out"
        printf '%s\n' "$_cc_res" > "$_cc_out"
        printf '  indexed: %s -> %s\n' "$_cc_sh" "$_cc_out"
    done
    printf 'Carapace index refreshed (no ksh bridge is documented).\n'
}

_completer_zoxide() {
    command -v zoxide >/dev/null 2>&1 || { printf 'zoxide not found; nothing to do\n'; return 0; }
    _cz_shell=$1
    _cz_tok=$(_completer_token "$_cz_shell")
    # No ksh-specific init exists: fall back to documented generic POSIX target.
    case "$_cz_shell" in
        ksh|sh) _cz_tok=posix ;;
    esac
    _cz_text=$(zoxide init "$_cz_tok" --hook prompt 2>/dev/null) || return 1
    [ -n "$_cz_text" ] || { printf 'no zoxide init for %s\n' "$_cz_shell"; return 1; }
    _cz_out="$(_completer_root)/completions/$_cz_shell-zoxide-init.$(_completer_ext "$_cz_shell")"
    _completer_backup "$_cz_out"
    printf '%s\n' "$_cz_text" > "$_cz_out"
    printf '  wrote zoxide init -> %s\n' "$_cz_out"
    _completer_link "$(_completer_main_config "$_cz_shell")" "$_cz_out" "$_cz_shell"
}

completer() {
    typeset action=$1; shift
    typeset -a progs; if [ $# -eq 0 ]; then progs=(opencode); else progs=("$@"); fi
    typeset root dir
    root=$(_completer_root); dir="$root/completions"
    mkdir -p "$dir"

    case "$action" in
        list) ls -l "$dir"; return 0 ;;
        self) _completer_register_self; return 0 ;;
        zoxide)
            if [ "${progs[0]}" = opencode ]; then set -- pwsh nu xonsh; fi
            for z in "$@"; do _completer_zoxide "$z"; done
            return 0 ;;
        update)
            if [ "${progs[0]}" = carapace ]; then _completer_update_carapace
            else printf 'Unknown update target. Try: completer update carapace\n'; fi
            return 0 ;;
        alias)
            case "${progs[0]}" in
                add) _add_alias "${progs[1]}" "${progs[*]:2}" ;;
                remove) _remove_alias "${progs[1]}" ;;
                *) printf 'usage: completer alias add <name> <value> | remove <name>\n' ;;
            esac
            return 0 ;;
    esac

    typeset shell=$action tok ext prog out text
    tok=$(_completer_token "$shell"); ext=$(_completer_ext "$shell")
    for prog in "${progs[@]}"; do
        printf 'Generating %s completions for %s...\n' "$prog" "$shell"
        out="$dir/$shell-$prog-completion.$ext"
        text=$(_completer_program_output "$prog" "$shell" "$tok") || { printf '  no completion for %s (%s)\n' "$prog" "$shell"; continue; }
        _completer_backup "$out"
        { printf '\n# >>> completer:%s:%s generated %s >>>\n' "$prog" "$shell" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
          printf '%s\n' "$text"
          printf '\n# <<< completer:%s:%s <<<\n' "$prog" "$shell"; } >> "$out"
        printf '  wrote -> %s\n' "$out"
        _completer_link "$(_completer_main_config "$shell")" "$out" "$shell"
    done
    _completer_register_self
}

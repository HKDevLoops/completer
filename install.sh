#!/bin/sh
# ============================================================================
# install.sh - simple curl-style linker for the POSIX-family completer files.
# Usage (remote):  export COMPLETER_RAW_BASE=https://<RAW-BASE>
#                  curl -fsSL "$COMPLETER_RAW_BASE/install.sh" | sh -s bash
#                  (use zsh | fish | sh instead, or omit -s to auto-detect)
# Usage (local):   sh ./install.sh           (auto-detect from $SHELL)
#                  sh ./install.sh zsh       (force a shell)
#                  COMPLETER_SHA256=<hex> sh ./install.sh bash  (verify fetch)
# Detects OS + main config, asks permission, backs up the old completer file,
# writes the new one, and adds ONE guarded source line. POSIX-sh compatible.
# Native APIs only: curl/wget, cp, grep, date, mkdir, mktemp, mv, chmod, tr,
#                   sha256sum/shasum/openssl, printf, read, uname.
#
# Trust model: this script runs as the invoking user and installs a file that
# the user's shell will later `source`, so downloaded bytes are executable code.
# By default the only authentication is TLS to COMPLETER_RAW_BASE; `-f` makes
# HTTP errors fatal and `--proto '=https' --tlsv1.2` forbids cleartext fetches
# and downgrade redirects. For a verifiable install set COMPLETER_SHA256 to the
# expected sha256 (upper- or lowercase) of completer.<shell>; the staged bytes
# are checked before install/link and discarded on mismatch. With no checksum
# you trust the host and its TLS chain. Fetching goes through a private mktemp
# path under umask 077; installed files and directories are chmod 600/700 so
# alias data is not world-readable and cannot be clobbered via a pre-created
# symlink at the target path.
# ============================================================================

set -e
umask 077

RAW_BASE=${COMPLETER_RAW_BASE:-https://<RAW-BASE>}

# ---------------------------------------------------------------------------
ic_say() { printf '%s\n' "$*"; }

ic_detect_shell() {
    _ic_sh=${SHELL##*/}
    case "$_ic_sh" in
        bash|zsh|fish|sh) printf '%s' "$_ic_sh" ;;
        *) printf 'sh' ;;
    esac
}

ic_main_config() {
    case "$1" in
        bash) printf '%s' "$HOME/.bashrc" ;;
        zsh)  printf '%s' "$HOME/.zshrc" ;;
        fish) printf '%s' "$HOME/.config/fish/config.fish" ;;
        *)    printf '%s' "$HOME/.profile" ;;
    esac
}

ic_source_line() {
    case "$1" in
        fish) printf "source '%s'" "$2" ;;
        *)    printf ". '%s'" "$2" ;;
    esac
}

ic_backup() {
    [ -f "$1" ] || return 0
    _ic_stamp=$(date +%Y%m%d-%H%M%S)
    cp "$1" "$1.bak.$_ic_stamp"
    printf '  backup -> %s.bak.%s\n' "$1" "$_ic_stamp"
}

ic_fetch() {
    if command -v curl >/dev/null 2>&1; then
        curl -f -s -S -L --proto '=https' --tlsv1.2 "$1" -o "$2"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$1" -O "$2"
    else
        printf 'error: need curl or wget to fetch %s\n' "$1" >&2
        return 1
    fi
}

# Private staging directory. mktemp is atomic; the fallback uses mkdir (also
# atomic) so an attacker cannot pre-place a symlink at a predictable path.
ic_tmp_dir() {
    _ic_td=
    if command -v mktemp >/dev/null 2>&1; then
        _ic_td=$(mktemp -d "${TMPDIR:-/tmp}/completer.XXXXXX" 2>/dev/null) || _ic_td=
        if [ -n "$_ic_td" ]; then
            printf '%s' "$_ic_td"
            return 0
        fi
    fi
    _ic_td="${TMPDIR:-/tmp}/completer.$$"
    (umask 077; mkdir "$_ic_td") 2>/dev/null || return 1
    printf '%s' "$_ic_td"
}

# Native sha256 helpers; prints lowercase hex or fails if no tool exists.
ic_hash() {
    _ic_line=
    if command -v sha256sum >/dev/null 2>&1; then
        _ic_line=$(sha256sum "$1" 2>/dev/null) || return 1
        _ic_h=${_ic_line%% *}
    elif command -v shasum >/dev/null 2>&1; then
        _ic_line=$(shasum -a 256 "$1" 2>/dev/null) || return 1
        _ic_h=${_ic_line%% *}
    elif command -v openssl >/dev/null 2>&1; then
        _ic_line=$(openssl dgst -sha256 "$1" 2>/dev/null) || return 1
        _ic_h=${_ic_line##* }
    else
        return 1
    fi
    printf '%s' "$_ic_h" | tr 'A-Z' 'a-z'
}

# Optional integrity gate: $1=file, $2=expected sha256 (empty means skip).
ic_verify() {
    _ic_file=$1; _ic_want=$2
    [ -n "$_ic_want" ] || return 0
    if ! command -v sha256sum >/dev/null 2>&1 &&
       ! command -v shasum >/dev/null 2>&1 &&
       ! command -v openssl >/dev/null 2>&1; then
        printf 'error: COMPLETER_SHA256 set but no sha256 tool available\n' >&2
        return 1
    fi
    _ic_got=$(ic_hash "$_ic_file") || return 1
    _ic_want=$(printf '%s' "$_ic_want" | tr 'A-Z' 'a-z')
    if [ "$_ic_got" != "$_ic_want" ]; then
        printf 'error: sha256 mismatch for %s\n  got      %s\n  expected %s\n' \
            "$_ic_file" "$_ic_got" "$_ic_want" >&2
        return 1
    fi
    ic_say '  sha256 verified'
}

ic_script_dir() {
    _ic_dir=$(CDPATH= cd "$(dirname "$0")" 2>/dev/null && pwd -P) || _ic_dir=$(pwd -P)
    printf '%s' "$_ic_dir"
}

# ---------------------------------------------------------------------------
SHELL_TARGET=${1:-$(ic_detect_shell)}
case "$SHELL_TARGET" in
    bash|zsh|fish|sh) ;;
    *) printf 'unsupported shell: %s (use bash|zsh|fish|sh)\n' "$SHELL_TARGET" >&2; exit 1 ;;
esac

EXT=$SHELL_TARGET
OS=$(uname -s 2>/dev/null || printf unknown)
MAIN=$(ic_main_config "$SHELL_TARGET")
# Phase 3 layout: everything lives in a sibling `completer/` folder beside the
# shell's main config, with one guarded source block in that config.
COMPLETER_DIR=$(dirname "$MAIN")/completer
TARGET="$COMPLETER_DIR/completer.$EXT"
ALIAS_FILE="$COMPLETER_DIR/alias.$EXT"
MARKER='# >>> completer:install >>>'
ENDMARK='# <<< completer:install <<<'

ic_say 'completer installer'
ic_say "  OS            : $OS"
ic_say "  Shell         : $SHELL_TARGET"
ic_say "  Main config   : $MAIN"
ic_say "  Completer dir : $COMPLETER_DIR"
ic_say "  Function file : $TARGET"

# Ask permission on the terminal so `curl ... | sh` still works.
ANSWER=${COMPLETER_YES:-}
if [ -z "$ANSWER" ]; then
    if [ -r /dev/tty ]; then
        printf 'Add the completer function here and link it? [y/N] ' > /dev/tty
        read ANSWER < /dev/tty || ANSWER=N
    else
        printf 'Add the completer function here and link it? [y/N] '
        read ANSWER || ANSWER=N
    fi
fi
case "$ANSWER" in
    y|Y|yes|YES|1) ;;
    *) ic_say 'Aborted.'; exit 0 ;;
esac

# Create the private destination directory before installing anything. Only
# chmod a directory we actually created — never change the permissions of an
# existing home/config directory (e.g. $HOME for bash/zsh/sh), which would be
# an unexpected and potentially disruptive side effect.
CONFIG_DIR=$(dirname "$MAIN")
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    chmod 700 "$CONFIG_DIR" 2>/dev/null || true
fi
# Phase 3: sibling folder beside the config, with a private completions store
# and a seed alias file. COMPLETER_ROOT is exported from the guarded block so
# runtime writes and alias edits land in this same folder.
if [ ! -d "$COMPLETER_DIR" ]; then
    mkdir -p "$COMPLETER_DIR/completions"
    chmod 700 "$COMPLETER_DIR" 2>/dev/null || true
else
    mkdir -p "$COMPLETER_DIR/completions"
fi
if [ ! -f "$ALIAS_FILE" ] && [ -f "$(ic_script_dir)/alias.$EXT" ]; then
    cp "$(ic_script_dir)/alias.$EXT" "$ALIAS_FILE"
    chmod 600 "$ALIAS_FILE" 2>/dev/null || true
fi

# Stage locally, verify, then move into place. Never write fetched code
# directly to the path that the shell rc sources.
ic_tmp=$(ic_tmp_dir) || { printf 'error: cannot create private temp dir\n' >&2; exit 1; }
trap 'rm -rf "$ic_tmp"' 0 1 2 15
STAGE="$ic_tmp/completer.$EXT"

SRC="$(ic_script_dir)/completer.$EXT"
if [ -f "$SRC" ]; then
    cp "$SRC" "$STAGE"
else
    ic_say "  Fetching $RAW_BASE/completer.$EXT ..."
    ic_fetch "$RAW_BASE/completer.$EXT" "$STAGE"
fi
ic_verify "$STAGE" "${COMPLETER_SHA256:-}" || exit 1

ic_backup "$TARGET"
mv "$STAGE" "$TARGET"
chmod 600 "$TARGET" 2>/dev/null || true
ic_say "  wrote -> $TARGET"

# Ensure the main config exists before appending; keep it private.
[ -f "$MAIN" ] || : > "$MAIN"
chmod 600 "$MAIN" 2>/dev/null || true

# Add ONE guarded source block: export the root, load the functions, and load
# the persistent alias store (so `completer alias add` survives a restart).
if ! grep -qF "$MARKER" "$MAIN" || ! grep -qF "$ENDMARK" "$MAIN"; then
    ic_backup "$MAIN"
    LINE=$(ic_source_line "$SHELL_TARGET" "$TARGET")
    ALINE=$(ic_source_line "$SHELL_TARGET" "$ALIAS_FILE")
    {
        printf '\n%s\n' "$MARKER"
        printf "# Generated by completer installer. Edit with 'completer alias ...'.\n"
        if [ "$SHELL_TARGET" = fish ]; then
            printf "set -gx COMPLETER_ROOT '%s'\n" "$COMPLETER_DIR"
        else
            printf "export COMPLETER_ROOT='%s'\n" "$COMPLETER_DIR"
        fi
        printf '%s\n' "$LINE"
        printf '%s\n' "$ALINE"
        printf '%s\n' "$ENDMARK"
        printf '\n'
    } >> "$MAIN"
    ic_say '  linked from main config (functions + aliases).'
else
    ic_say '  already linked (marker present); nothing to do.'
fi
ic_say "Done. Restart the shell and run 'completer $SHELL_TARGET'."

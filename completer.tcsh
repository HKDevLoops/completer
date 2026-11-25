# ============================================================================
# completer.tcsh - tcsh/csh-native modular completion manager.
#
# ZERO STARTUP WORK: loading (sourcing with no arguments) this file only creates
# the `completer` alias. All real work happens when that alias is invoked, which
# re-sources this same file WITH arguments and jumps to the dispatch section.
#
# Native APIs used (all documented in the official tcsh man page / carapace / zoxide):
#   alias NAME 'TEXT' / unalias PATTERN   (alias add/remove)
#   complete CMD 'p/1/(list)/' / uncomplete CMD  (programmed completion, self-completion)
#   source FILE [args...]                (re-dispatch + generated-file sourcing)
#   eval / command substitution with backticks / $?VAR / $#VAR / $VAR:t
#   setenv CARAPACE_BRIDGES; eval `carapace _carapace`
#   zoxide init tcsh > FILE ; source FILE
#
# Official docs:
#   https://linux.die.net/man/1/tcsh
#   https://carapace-sh.github.io/carapace-bin/setup.html
#   https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/README.md
#
# GAPs vs the universal surface:
#   - Tcsh has NO user-defined functions; the surface is a `completer` ALIAS
#     wrapping `source <this file> \!*`. Set COMPLETER_SELF if installed elsewhere.
#   - `complete` is documented as experimental (syntax may change).
#   - No Windows rc path is documented; only ~/.tcshrc / ~/.cshrc.
#   - No verbatim `completer` example exists; snippets apply the documented grammar.
# ============================================================================

if ( $#argv > 0 ) goto completer_dispatch

# ---- load mode: definitions only -------------------------------------------
if ( $?COMPLETER_SELF ) then
    set _cself = "$COMPLETER_SELF"
else
    set _cself = "$HOME/.config/completer/completer.tcsh"
endif
if ( $?COMPLETER_ROOT ) then
    set _croot = "$COMPLETER_ROOT"
else if ( $?XDG_CONFIG_HOME ) then
    set _croot = "$XDG_CONFIG_HOME/completer"
else
    set _croot = "$HOME/.config/completer"
endif

alias completer "source $_cself \!*"
goto completer_eof

# ---- dispatch mode: invoked as `completer <action> [args...]` --------------
completer_dispatch:
    set _c_action = "$1"
    shift
    set _c_progs = ( $argv )
    if ( $#_c_progs == 0 ) set _c_progs = ( opencode )

    # SECURITY: validate every program name before it reaches a shell parser,
    # a generated filename, or a sourced completion block. Allowed: one or more
    # [A-Za-z0-9_.-]; rejected: metacharacters (; | & $ ` < > ( ) etc.), spaces,
    # path separators (/ and \), '..' traversal and newlines. The trailing '@'
    # sentinel survives tr so a trailing newline cannot be stripped by `...`.
    foreach _c_n ( $_c_progs )
        set _c_clean = "`printf '%s@' "$_c_n" | tr -d 'A-Za-z0-9_.-'`"
        printf '%s' "$_c_n" | grep -Fq '..'
        set _c_dotdot = $status
        if ( "$_c_n" == "" || "$_c_clean" != "@" || $_c_dotdot == 0 ) then
            echo "rejected unsafe program name: [$_c_n]"
            goto completer_eof
        endif
    end

    set _c_root = "$HOME/.config/completer"
    if ( $?COMPLETER_ROOT ) set _c_root = "$COMPLETER_ROOT"
    if ( $?XDG_CONFIG_HOME ) then
        set _c_cfg = "$XDG_CONFIG_HOME"
    else
        set _c_cfg = "$HOME/.config"
    endif
    set _c_dir = "$_c_root/completions"
    if ( ! -d "$_c_dir" ) mkdir -p "$_c_dir"

    if ( "$_c_action" == "list" ) then
        ls -l "$_c_dir"
        goto completer_eof
    endif

    if ( "$_c_action" == "self" ) then
        complete completer 'p/1/(add remove list update zoxide self)/'
        echo 'Self-completion registered (native tcsh complete).'
        goto completer_eof
    endif

    if ( "$_c_action" == "alias" ) then
        if ( "$1" == "add" ) then
            set _c_name = "$2"; shift 2; set _c_val = "$argv"
            # SECURITY: the name and value are written to alias.tcsh, which is
            # sourced next launch -> strict name check + newline/quote guard.
            set _c_clean = "`printf '%s@' "$_c_name" | tr -d 'A-Za-z0-9_.-'`"
            printf '%s' "$_c_name" | grep -Fq '..'
            set _c_dotdot = $status
            set _c_vlines = "`printf '%s@' "$_c_val" | wc -l | tr -cd '0-9'`"
            printf '%s' "$_c_val" | grep -Fq "'"
            set _c_vquote = $status
            if ( "$_c_name" == "" || "$_c_clean" != "@" || $_c_dotdot == 0 || "$_c_vlines" != "0" || $_c_vquote == 0 ) then
                echo 'rejected unsafe alias name or value'
                goto completer_eof
            endif
            alias "$_c_name" "$_c_val"
            set _c_af = "$_c_root/alias.tcsh"
            set _c_pat = "alias $_c_name"
            if ( -f "$_c_af" ) then
                set _c_tmp = "$_c_af.tmp"
                grep -vF "$_c_pat" "$_c_af" > "$_c_tmp"
                mv "$_c_tmp" "$_c_af"
            endif
            echo "alias $_c_name '$_c_val'" >> "$_c_af"
            echo "  alias $_c_name -> $_c_val"
        else if ( "$1" == "remove" ) then
            set _c_name = "$2"
            set _c_clean = "`printf '%s@' "$_c_name" | tr -d 'A-Za-z0-9_.-'`"
            printf '%s' "$_c_name" | grep -Fq '..'
            set _c_dotdot = $status
            if ( "$_c_name" == "" || "$_c_clean" != "@" || $_c_dotdot == 0 ) then
                echo 'rejected unsafe alias name'
                goto completer_eof
            endif
            unalias "$_c_name"
            set _c_af = "$_c_root/alias.tcsh"
            if ( -f "$_c_af" ) then
                set _c_tmp = "$_c_af.tmp"
                grep -vF "alias $_c_name" "$_c_af" > "$_c_tmp"
                mv "$_c_tmp" "$_c_af"
            endif
            echo "  alias $_c_name removed"
        else
            echo 'usage: completer alias add <name> <value> | remove <name>'
        endif
        goto completer_eof
    endif

    if ( "$_c_action" == "update" ) then
        if ( "$1" != "carapace" ) then
            echo 'Unknown update target. Try: completer update carapace'
            goto completer_eof
        endif
        which carapace >& /dev/null
        if ( $status != 0 ) then
            echo 'carapace not found; nothing to update'
            goto completer_eof
        endif
        echo 'Refreshing carapace indexes (native carapace CLI)...'
        carapace --clear-cache >& /dev/null
        set _c_listed = "`carapace --list`"
        echo "  carapace index queried"
        foreach _c_sh ( bash zsh fish powershell nushell xonsh )
            set _c_out = "$_c_dir/carapace-$_c_sh-init.$_c_sh"
            set _c_text = "`carapace _carapace $_c_sh`"
            if ( "$_c_text" == "" ) continue
            if ( -f "$_c_out" ) then
                set _c_stamp = "`date +%Y%m%d-%H%M%S`"
                cp "$_c_out" "$_c_out.bak.$_c_stamp"
            endif
            echo "$_c_text" > "$_c_out"
            echo "  indexed: $_c_sh -> $_c_out"
        end
        echo 'Carapace index refreshed.'
        goto completer_eof
    endif

    if ( "$_c_action" == "zoxide" ) then
        which zoxide >& /dev/null
        if ( $status != 0 ) then
            echo 'zoxide not found; nothing to do'
            goto completer_eof
        endif
        set _c_zs = ( $argv )
        if ( $#_c_zs == 0 ) set _c_zs = ( pwsh nu xonsh )
        foreach _c_z ( $_c_zs )
            set _c_clean = "`printf '%s@' "$_c_z" | tr -d 'A-Za-z0-9_.-'`"
            printf '%s' "$_c_z" | grep -Fq '..'
            set _c_dotdot = $status
            if ( "$_c_z" == "" || "$_c_clean" != "@" || $_c_dotdot == 0 ) then
                echo "  rejected unsafe zoxide name: [$_c_z]"
                continue
            endif
            set _c_tok = "$_c_z"
            switch ( "$_c_z" )
            case nu:
            case nushell:
                set _c_tok = nushell
                breaksw
            case pwsh:
            case powershell:
                set _c_tok = powershell
                breaksw
            case sh:
                set _c_tok = posix
                breaksw
            endsw
            set _c_text = "`zoxide init $_c_tok`"
            if ( "$_c_text" == "" ) then
                echo "no zoxide init for $_c_z"
                continue
            endif
            set _c_out = "$_c_dir/$_c_z-zoxide-init.$_c_z"
            if ( -f "$_c_out" ) then
                set _c_stamp = "`date +%Y%m%d-%H%M%S`"
                cp "$_c_out" "$_c_out.bak.$_c_stamp"
            endif
            echo "$_c_text" > "$_c_out"
            echo "  wrote zoxide init -> $_c_out"
        end
        goto completer_eof
    endif

    # ---- otherwise $action is a TARGET SHELL ------------------------------
    set _c_shell = "$_c_action"
    # SECURITY: shell name is used in generated paths and sourced markers.
    set _c_clean = "`printf '%s@' "$_c_shell" | tr -d 'A-Za-z0-9_.-'`"
    printf '%s' "$_c_shell" | grep -Fq '..'
    set _c_dotdot = $status
    if ( "$_c_shell" == "" || "$_c_clean" != "@" || $_c_dotdot == 0 ) then
        echo "rejected unsafe shell name: [$_c_shell]"
        goto completer_eof
    endif
    set _c_tok = "$_c_shell"
    switch ( "$_c_shell" )
    case nu:
    case nushell:
        set _c_tok = nushell
        set _c_ext = nu
        breaksw
    case pwsh:
    case powershell:
        set _c_tok = powershell
        set _c_ext = ps1
        breaksw
    case xonsh:
        set _c_ext = xsh
        breaksw
    default:
        set _c_ext = "$_c_shell"
        breaksw
    endsw

    # main config file for the chosen target shell
    switch ( "$_c_shell" )
    case tcsh:
    case csh:
        set _c_cfgfile = "$HOME/.tcshrc"
        breaksw
    case bash:
        set _c_cfgfile = "$HOME/.bashrc"
        breaksw
    case zsh:
        set _c_cfgfile = "$HOME/.zshrc"
        breaksw
    case sh:
        set _c_cfgfile = "$HOME/.profile"
        breaksw
    case ksh:
        set _c_cfgfile = "$HOME/.kshrc"
        breaksw
    case default:
        set _c_cfgfile = "$_c_cfg/completer/$_c_shell-completion.$_c_ext"
        breaksw
    endsw

    foreach _c_prog ( $_c_progs )
        echo "Generating $_c_prog completions for $_c_shell..."
        set _c_out = "$_c_dir/$_c_shell-$_c_prog-completion.$_c_ext"
        set _c_text = ""
        foreach _c_a ( "completion --shell $_c_tok" "completion -s $_c_tok" "completion $_c_tok" "completions $_c_tok" "--generate-completion $_c_tok" "--completions $_c_tok" )
            # SECURITY: split the fixed probe into a word list and invoke the
            # validated program directly. No eval of interpolated user text.
            set _c_words = ( $_c_a )
            set _c_text = "`$_c_prog $_c_words 2>/dev/null`"
            if ( "$_c_text" != "" ) break
        end
        if ( "$_c_text" == "" ) then
            which carapace >& /dev/null
            if ( $status == 0 ) set _c_text = "`carapace $_c_prog $_c_tok`"
        endif
        if ( "$_c_text" == "" ) then
            echo "  no completion for $_c_prog ($_c_shell)"
            continue
        endif
        if ( -f "$_c_out" ) then
            set _c_stamp = "`date +%Y%m%d-%H%M%S`"
            cp "$_c_out" "$_c_out.bak.$_c_stamp"
            echo "  backup -> $_c_out.bak.$_c_stamp"
        endif
        echo "# >>> completer:$_c_prog:$_c_shell generated `date -u +%Y-%m-%dT%H:%M:%SZ` >>>" >> "$_c_out"
        echo "$_c_text" >> "$_c_out"
        echo "# <<< completer:$_c_prog:$_c_shell <<<" >> "$_c_out"
        echo "  wrote -> $_c_out"
        # idempotent link into main config
        set _c_tail = "$_c_out:t"
        set _c_marker = "# >>> completer:$_c_shell:$_c_tail >>>"
        if ( -f "$_c_cfgfile" ) then
            grep -qF "$_c_marker" "$_c_cfgfile"
            if ( $status != 0 ) then
                echo "" >> "$_c_cfgfile"
                echo "$_c_marker" >> "$_c_cfgfile"
                echo "source $_c_out" >> "$_c_cfgfile"
                echo "# <<< completer:$_c_shell:$_c_tail <<<" >> "$_c_cfgfile"
                echo "  linked -> $_c_cfgfile"
            endif
        endif
    end

    # self-completion (feasible via native complete)
    complete completer 'p/1/(add remove list update zoxide self)/'

completer_eof:

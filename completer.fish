# ============================================================================
# completer.fish - fish-native modular completion manager.
# Native APIs: complete, complete -c/-a/-l/-s/-n/-f/-d, fish_complete_path,
# functions -q, functions -e, alias/unalias, string, path, command -q.
# Fish loads completions from ~/.config/fish/completions/<cmd>.fish
# ============================================================================

function _completer_root
    if set -q COMPLETER_ROOT; and test -n "$COMPLETER_ROOT"
        printf '%s' "$COMPLETER_ROOT"
    else
        set -l cfg "$HOME/.config"; if set -q XDG_CONFIG_HOME; set cfg "$XDG_CONFIG_HOME"; end
        printf '%s' "$cfg/completer"
    end
end

function _completer_token -a shell
    switch $shell
        case nu nushell; printf 'nushell'
        case pwsh powershell; printf 'powershell'
        case '*'; printf '%s' $shell
    end
end

function _completer_ext -a shell
    switch $shell
        case nu nushell; printf 'nu'
        case xonsh; printf 'xsh'
        case pwsh powershell; printf 'ps1'
        case '*'; printf '%s' $shell
    end
end

# Reject names that could traverse the completions dir or inject code when the
# generated file is sourced. No '/', '\', '..', newline, or shell metachar.
function _completer_valid_name -a name
    test -n "$name"; or return 1
    string match -qr '\.\.' -- "$name"; and return 1
    string match -qr '[/\\ ;|&$`<>()\n]' -- "$name"; and return 1
    return 0
end

function _completer_capture
    set -l out ($argv 2>/dev/null); or return 1
    test -n "$out"; or return 1
    string match -qr '^(DESCRIPTION|USAGE)' -- "$out"; and return 1
    printf '%s\n' $out
end

function _completer_program_output -a prog shell tok
    # Resolve the program once; the first successful probe returns immediately.
    if command -q $prog
        for a in "completion --shell $tok" "completion -s $tok" "completion $tok" \
                 "completions $tok" "--generate-completion $tok" "--completions $tok"
            set -l out (_completer_capture $prog (string split ' ' -- $a)); and begin
                printf '%s\n' $out; return 0
            end
        end
    end
    if command -q carapace
        set -l out (_completer_capture carapace $prog $tok); and begin
            printf '%s\n' $out; return 0
        end
    end
    return 1
end

function _completer_backup -a path
    test -f "$path"; or return 0
    cp -- "$path" "$path.bak"; and printf '  backup -> %s.bak\n' $path
end

function _completer_main_config -a shell
    set -l cfg "$HOME/.config"; if set -q XDG_CONFIG_HOME; set cfg "$XDG_CONFIG_HOME"; end
    switch $shell
        case fish; printf '%s' "$HOME/.config/fish/config.fish"
        case bash; printf '%s' "$HOME/.bashrc"
        case zsh; printf '%s' "$HOME/.zshrc"
        case sh; printf '%s' "$HOME/.profile"
        case pwsh powershell; printf '%s' "$HOME/Documents/PowerShell/profile.ps1"
        case nu; printf '%s' "$cfg/nushell/config.nu"
        case xonsh; printf '%s' "$cfg/xonsh/.xonshrc"
        case '*'; printf '%s' "$cfg/completer/$shell-completion."(_completer_ext $shell)
    end
end

function _completer_link -a config file shell
    test -f "$config"; or return 0
    set -l name (path basename $file)
    set -l marker "# >>> completer:$shell:$name >>>"
    grep -qF -- "$marker" "$config"; and return 0
    set -l load
    switch $shell
        case nu fish; set load "source '$file'"
        case xonsh; set load "execx(open('$file').read(), 'exec', __xonsh__.ctx)"
        case '*'; set load ". '$file'"
    end
    printf '\n%s\n%s\n# <<< completer:%s:%s <<<\n' "$marker" "$load" "$shell" "$name" >> $config
    printf '  linked -> %s\n' $config
end

function add-alias -a name
    if not _completer_valid_name $name
        printf 'invalid alias name: %s\n' $name; return 1
    end
    set -l value (string join ' ' $argv[2..-1])
    set -l file (_completer_root)/alias.fish
    mkdir -p (path dirname $file)
    test -f $file; or printf '# alias.fish - managed by completer\n' > $file
    set -l keep (grep -vE "^[[:space:]]*alias[[:space:]]+$name=" $file)
    printf '%s\n' $keep > $file
    printf "alias %s '%s'\n" $name $value >> $file
    alias $name=$value
    printf '  alias %s -> %s in %s\n' $name $value $file
end

function remove-alias -a name
    if not _completer_valid_name $name
        printf 'invalid alias name: %s\n' $name; return 1
    end
    set -l file (_completer_root)/alias.fish
    test -f $file; or return 0
    set -l keep (grep -vE "^[[:space:]]*alias[[:space:]]+$name=" $file)
    printf '%s\n' $keep > $file
    functions -q $name; and functions -e $name
    printf '  alias %s removed\n' $name
end

function completer-update-carapace
    if not command -q carapace
        printf 'carapace not found; nothing to update\n'; return 0
    end
    printf 'Refreshing carapace indexes (native carapace CLI)...\n'
    mkdir -p (_completer_root)/completions
    carapace --clear-cache >/dev/null 2>&1
    set -l n (carapace --list 2>/dev/null | count)
    printf '  indexed completers: %s\n' $n
    for sh in bash zsh fish powershell nushell xonsh
        set -l out (_completer_root)/completions/carapace-$sh-init.(_completer_ext $sh)
        set -l res (carapace _carapace $sh 2>/dev/null); or continue
        test -n "$res"; or continue
        _completer_backup $out
        printf '%s\n' $res > $out
        printf '  indexed: %s -> %s\n' $sh $out
    end
    printf 'Carapace index refreshed.\n'
end

function _completer_zoxide -a shell
    if not command -q zoxide
        printf 'zoxide not found; nothing to do\n'; return 0
    end
    if not _completer_valid_name $shell
        printf 'invalid shell name: %s\n' $shell; return 1
    end
    set -l tok (_completer_token $shell)
    test "$shell" = sh; and set tok posix
    set -l res
    if test "$shell" = bash; or test "$shell" = zsh
        set res (zoxide init $shell 2>/dev/null); or return 1
    else
        set res (zoxide init $tok 2>/dev/null); or return 1
    end
    if test -z "$res"
        printf 'no zoxide init for %s\n' $shell; return 1
    end
    set -l out (_completer_root)/completions/$shell-zoxide-init.(_completer_ext $shell)
    _completer_backup $out
    printf '%s\n' $res > $out
    printf '  wrote zoxide init -> %s\n' $out
    _completer_link (_completer_main_config $shell) $out $shell
end

function completer -a action
    set -l progs $argv[2..-1]; if test -z "$progs"; set progs opencode; end
    set -l dir (_completer_root)/completions
    mkdir -p $dir

    switch $action
        case list; ls -l $dir; return 0
        case zoxide
            if test "$progs[1]" = opencode; set progs pwsh nu xonsh; end
            for z in $progs; _completer_zoxide $z; end
            return 0
        case update
            if test "$progs[1]" = carapace; completer-update-carapace
            else; printf 'Unknown update target. Try: completer update carapace\n'; end
            return 0
        case alias
            switch $progs[1]
                case add; add-alias $progs[2] $progs[3..-1]
                case remove; remove-alias $progs[2]
                case '*'; printf 'usage: completer alias add <name> <value> | remove <name>\n'
            end
            return 0
    end

    set -l shell $action
    if not _completer_valid_name $shell
        printf 'invalid shell name: %s\n' $shell; return 1
    end
    set -l tok (_completer_token $shell); set -l ext (_completer_ext $shell)
    for prog in $progs
        if not _completer_valid_name $prog
            printf '  invalid program name: %s (skipped)\n' $prog; continue
        end
        printf 'Generating %s completions for %s...\n' $prog $shell
        set -l out $dir/$shell-$prog-completion.$ext
        set -l text (_completer_program_output $prog $shell $tok); or begin
            printf '  no completion for %s (%s)\n' $prog $shell; continue
        end
        _completer_backup $out
        set -l begin "# >>> completer:$prog:$shell"
        if test -f "$out"; and grep -qF -- "$begin" "$out"
            # Replace the previously generated block for this program/shell in place.
            printf '\n# >>> completer:%s:%s generated %s >>>\n' $prog $shell (date -Is) > $out
        else
            printf '\n# >>> completer:%s:%s generated %s >>>\n' $prog $shell (date -Is) >> $out
        end
        printf '%s\n' $text >> $out
        printf '\n# <<< completer:%s:%s <<<\n' $prog $shell >> $out
        printf '  wrote -> %s\n' $out
        _completer_link (_completer_main_config $shell) $out $shell
    end
end

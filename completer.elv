# ============================================================================
# completer.elv - Elvish-native modular completion manager.
#
# ZERO STARTUP WORK: sourcing this file only DEFINES functions. No probing,
# no config writes, and NO `edit:` registration happens at load time.
#
# Native APIs used (all documented in the official references below):
#   fn / var / set / if-elif / for / put / echo / count / eq / has-env / has-external
#   external / eval / slurp / del                      -> elv.sh/ref/builtin.html, language.html
#   str:contains-any / str:contains                    -> elv.sh/ref/str.html
#   set edit:completion:arg-completer[cmd] = {|@args| ... }  -> elv.sh/ref/edit.html
#   set edit:command-abbr['name'] = 'value'            -> elv.sh/ref/edit.html (alias replacement)
#   eval (carapace _carapace|slurp)                    -> carapace-sh.github.io setup#elvish
#   eval (zoxide init elvish | slurp)                  -> zoxide README
#
# Official docs:
#   https://elv.sh/ref/command.html
#   https://elv.sh/ref/edit.html
#   https://elv.sh/ref/builtin.html
#   https://elv.sh/ref/language.html
#   https://elv.sh/ref/str.html
#   https://carapace-sh.github.io/carapace-bin/setup.html#elvish
#   https://github.com/ajeetdsouza/zoxide#setup-zoxide-on-your-shell
#
# GAPs vs the universal surface:
#   - Elvish has NO `alias` builtin. Native equivalents are the `edit:command-abbr`
#     map (Fish-like command abbreviations) and functions; `completer alias` uses them.
#   - A single abbr key is removed with the language-level `del` special command
#     (language.html 8.5); there is no dedicated "unalias" API.
#   - Self-completion is feasible via `edit:completion:arg-completer[completer]`
#     but is registered ONLY by `completer self` / first generation, never at load.
# ============================================================================

fn _completer-root {
    if (has-env COMPLETER_ROOT) {
        put $E:COMPLETER_ROOT
    } elif (has-env XDG_CONFIG_HOME) {
        put $E:XDG_CONFIG_HOME'/completer'
    } else {
        put ~/.config/completer
    }
}

fn _completer-token {|shell|
    if (or (eq $shell nu) (eq $shell nushell)) { put nushell; return }
    if (or (eq $shell pwsh) (eq $shell powershell)) { put powershell; return }
    put $shell
}

fn _completer-ext {|shell|
    if (or (eq $shell nu) (eq $shell nushell)) { put nu; return }
    if (eq $shell xonsh) { put xsh; return }
    if (or (eq $shell pwsh) (eq $shell powershell)) { put ps1; return }
    put $shell
}

# Reject names that could escape the completions dir or inject generated text.
# Safe code points only; explicit '..' rejection.
fn _completer-valid-name {|name|
    if (eq $name '') { put $false; return }
    var bad = '/;|&$`<>()\'"\n"
    if (str:contains-any $name $bad) { put $false; return }
    if (str:contains $name '..') { put $false; return }
    put $true
}

# Emit captured stdout as one string; emit '' on any failure or absent program.
fn _completer-capture {|prog @args|
    if (not (has-external $prog)) { put ''; return }
    var ex = (external $prog)
    var raw = (var status = ?($ex $@args 2> /dev/null | slurp))
    if (eq $status $ok) { put $raw } else { put '' }
}

# Single fixed backup per target (overwrite; no .bak.<stamp> accumulation).
fn _completer-backup {|file|
    if (not ?(test -f $file)) { return }
    var ignored = ?(cp -- $file $file'.bak')
    echo '  backup -> '$file'.bak'
}

# Idempotent generated block: rewrite in place (one block) when the begin marker
# exists, otherwise append. Callers back up the target before invoking this.
fn _completer-write-block {|out prog shell text|
    var begin = '# >>> completer:'$prog':'$shell
    if ?(test -f $out) {
        if ?(grep -qF -- $begin $out) {
            echo '' > $out
        } else {
            echo '' >> $out
        }
    } else {
        echo '' >> $out
    }
    var stamp = (date -Is)
    echo '# >>> completer:'$prog':'$shell' generated '$stamp' >>>' >> $out
    echo $text >> $out
    echo '# <<< completer:'$prog':'$shell' <<<' >> $out
}

fn _completer-main-config {|shell|
    var cfg = ~/.config
    if (has-env XDG_CONFIG_HOME) { set cfg = $E:XDG_CONFIG_HOME }
    if (eq $shell bash) { put ~/.bashrc; return }
    if (eq $shell zsh) { put ~/.zshrc; return }
    if (eq $shell sh) { put ~/.profile; return }
    if (eq $shell fish) { put $cfg'/fish/config.fish'; return }
    if (eq $shell pwsh) { put ~/Documents/PowerShell/profile.ps1; return }
    if (eq $shell powershell) { put ~/Documents/PowerShell/profile.ps1; return }
    if (eq $shell nu) { put $cfg'/nushell/config.nu'; return }
    if (eq $shell xonsh) { put $cfg'/xonsh/.xonshrc'; return }
    if (eq $shell elvish) { put $cfg'/elvish/rc.elv'; return }
    if (eq $shell tcsh) { put ~/.tcshrc; return }
    if (eq $shell ksh) { put ~/.kshrc; return }
    if (eq $shell ion) { put ~/.config/ion/initrc; return }
    if (eq $shell oil) { put ~/.config/oils/oshrc; return }
    if (eq $shell yash) { put $cfg'/yash/rc'; return }
    put $cfg'/completer/'$shell'-completion.'(_completer-ext $shell)
}

fn _completer-link {|config file shell|
    if (not ?(test -f $config)) { return }
    var base = (basename $file)
    var marker = '# >>> completer:'$shell':'$base' >>>'
    if ?(grep -qF -- $marker $config) { return }
    _completer-backup $config
    var load = ". '$file'"
    if (or (eq $shell nu) (eq $shell fish)) { set load = "source '$file'" }
    if (eq $shell xonsh) { set load = "execx(open('$file').read(), 'exec', __xonsh__.ctx)" }
    if (eq $shell elvish) { set load = "eval (slurp < '$file')" }
    echo '' >> $config
    echo $marker >> $config
    echo $load >> $config
    echo '# <<< completer:'$shell':'$base' <<<' >> $config
    echo '  linked -> '$config
}

# Completion acquisition: documented probe order, then carapace single-completer.
fn _completer-program-output {|prog shell tok|
    var probes = [
        [completion --shell $tok]
        [completion -s $tok]
        [completion $tok]
        [completions $tok]
        [--generate-completion $tok]
        [--completions $tok]
    ]
    for p $probes {
        var text = (_completer-capture $prog $@p)
        if (and (not-eq $text '') (not ?(echo $text | grep -qE '^(DESCRIPTION|USAGE|usage:)' 2> /dev/null))) {
            put $text
            return
        }
    }
    var via = (_completer-capture carapace $prog $tok)
    put $via
}

fn _completer-register-self {
    # edit: may be absent in non-interactive elvish; the ?() guard makes this a no-op there.
    var ignored = ?(set edit:completion:arg-completer[completer] = {|@args|
        var n = (count $args)
        if (eq $n 2) {
            put add remove list update zoxide self
        } elif (eq $n 3) {
            if (eq $args[1] alias) { put add remove }
            if (eq $args[1] update) { put carapace }
        }
    })
}

fn _completer-update-carapace {
    if (not (has-external carapace)) { echo 'carapace not found; nothing to update'; return }
    echo 'Refreshing carapace indexes (native carapace CLI)...'
    var dir = (_completer-root)'/completions'
    var ignored = ?(mkdir -p $dir)
    var igc = ?(carapace --clear-cache 2> /dev/null)
    var listed = (_completer-capture carapace --list)
    var n = (echo $listed | wc -l)
    echo '  indexed completers: '$n
    for sh [bash zsh fish powershell nushell xonsh elvish] {
        var out = $dir'/carapace-'$sh'-init.'(_completer-ext $sh)
        var res = (_completer-capture carapace _carapace $sh)
        if (eq $res '') { continue }
        _completer-backup $out
        echo $res > $out
        echo '  indexed: '$sh' -> '$out
    }
    echo 'Carapace index refreshed.'
}

fn _completer-zoxide {|shell|
    if (not (has-external zoxide)) { echo 'zoxide not found; nothing to do'; return }
    if (not (_completer-valid-name $shell)) { echo 'invalid shell name: '$shell; return }
    var dir = (_completer-root)'/completions'
    var ignored = ?(mkdir -p $dir)
    var tok = (_completer-token $shell)
    if (eq $shell sh) { set tok = posix }
    var res = ''
    if (or (eq $shell bash) (eq $shell zsh)) {
        set res = (_completer-capture zoxide init $shell)
    } else {
        set res = (_completer-capture zoxide init $tok)
    }
    if (eq $res '') { echo 'no zoxide init for '$shell; return }
    var out = $dir'/'$shell'-zoxide-init.'(_completer-ext $shell)
    _completer-backup $out
    echo $res > $out
    echo '  wrote zoxide init -> '$out
    _completer-link (_completer-main-config $shell) $out $shell
}

fn _completer-alias-add {|name @value|
    if (not (_completer-valid-name $name)) { echo 'invalid alias name: '$name; return }
    var val = (echo $@value)
    var root = (_completer-root)
    var ignored = ?(mkdir -p $root)
    var file = $root'/alias.elv'
    var pat = "edit:command-abbr['"$name"']"
    if ?(test -f $file) {
        var tmp = $file'.tmp'
        var ig = ?(grep -vF -- $pat $file > $tmp)
        var ig2 = ?(mv -- $tmp $file)
    }
    echo "set edit:command-abbr['"$name"'] = '"$val"'" >> $file
    var ig3 = ?(set edit:command-abbr[$name] = $val)
    echo '  alias '$name' -> '$val
}

fn _completer-alias-remove {|name|
    if (not (_completer-valid-name $name)) { echo 'invalid alias name: '$name; return }
    var file = (_completer-root)'/alias.elv'
    var pat = "edit:command-abbr['"$name"']"
    if ?(test -f $file) {
        var tmp = $file'.tmp'
        var ig = ?(grep -vF -- $pat $file > $tmp)
        var ig2 = ?(mv -- $tmp $file)
    }
    var ig3 = ?(del edit:command-abbr[$name])
    echo '  alias '$name' removed'
}

fn completer {|action @args|
    var root = (_completer-root)
    var dir = $root'/completions'
    var ignored = ?(mkdir -p $dir)

    if (eq $action list) {
        if ?(test -d $dir) { ls -l $dir }
        return
    }
    if (eq $action self) {
        _completer-register-self
        echo 'Self-completion registered for this session (edit:completion:arg-completer).'
        return
    }
    if (eq $action zoxide) {
        var zs = $args
        if (eq (count $zs) 0) { set zs = [pwsh nu xonsh] }
        for z $zs { _completer-zoxide $z }
        return
    }
    if (eq $action update) {
        if (and (gt (count $args) 0) (eq $args[0] carapace)) {
            _completer-update-carapace
        } else {
            echo 'Unknown update target. Try: completer update carapace'
        }
        return
    }
    if (eq $action alias) {
        if (lt (count $args) 1) {
            echo 'usage: completer alias add <name> <value> | remove <name>'
            return
        } elif (eq $args[0] add) {
            if (lt (count $args) 2) { echo 'usage: completer alias add <name> <value>'; return }
            _completer-alias-add $args[1] $@args[2..]
        } elif (eq $args[0] remove) {
            if (lt (count $args) 2) { echo 'usage: completer alias remove <name>'; return }
            _completer-alias-remove $args[1]
        } else {
            echo 'usage: completer alias add <name> <value> | remove <name>'
        }
        return
    }

    var shell = $action
    if (not (_completer-valid-name $shell)) { echo 'invalid shell name: '$shell; return }
    var tok = (_completer-token $shell)
    var ext = (_completer-ext $shell)
    var progs = $args
    if (eq (count $progs) 0) { set progs = [opencode] }
    for prog $progs {
        if (not (_completer-valid-name $prog)) { echo 'invalid program name: '$prog; continue }
        echo 'Generating '$prog' completions for '$shell'...'
        var out = $dir'/'$shell'-'$prog'-completion.'$ext
        var text = (_completer-program-output $prog $shell $tok)
        if (eq $text '') { echo '  no completion for '$prog' ('$shell')'; continue }
        _completer-backup $out
        _completer-write-block $out $prog $shell $text
        echo '  wrote -> '$out
        _completer-link (_completer-main-config $shell) $out $shell
    }
    _completer-register-self
}

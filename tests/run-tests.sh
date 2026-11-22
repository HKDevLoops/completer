#!/bin/sh
# POSIX test harness for Completer. Runs native parsers where available and
# structural checks (markers, entrypoints, no compiled binaries) everywhere.
set -u
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FAIL=0
pass() { printf '  ok   %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }

echo "== structural checks =="
for f in completer.ps1 completer.nu completer.xsh completer.bash completer.zsh \
         completer.fish completer.sh completer.elv completer.cmd.l completer.tcsh \
         completer.ksh completer.ion completer.oil completer.yash; do
    p="$ROOT/$f"
    [ -s "$p" ] && pass "$f present" || fail "$f missing/empty"
done

for f in install.ps1 install.sh README.md LICENSE; do
    [ -s "$ROOT/$f" ] && pass "$f present" || fail "$f missing/empty"
done

# Every completer file must expose the shared entrypoints (in some syntax).
for f in "$ROOT"/completer.*; do
    for verb in update zoxide alias; do
        grep -q -- "$verb" "$f" && pass "$(basename "$f") has '$verb'" || fail "$(basename "$f") missing '$verb'"
    done
done

# No compiled executables anywhere.
if find "$ROOT" -type f \( -name '*.exe' -o -name '*.dll' -o -name '*.so' \
     -o -name '*.bin' -o -name '*.pyd' \) | grep -q .; then
    fail "compiled binary found"
else
    pass "no compiled binaries"
fi

echo "== native parser checks (available shells) =="
if command -v bash >/dev/null 2>&1; then
    for f in completer.bash completer.sh install.sh; do
        bash -n "$ROOT/$f" && pass "bash -n $f" || fail "bash -n $f"
    done
fi
if command -v sh >/dev/null 2>&1; then
    for f in completer.sh install.sh; do
        sh -n "$ROOT/$f" && pass "sh -n $f" || fail "sh -n $f"
    done
fi
if command -v pwsh >/dev/null 2>&1; then
    # Git Bash paths (/d/a/...) are meaningless to PowerShell; convert when possible.
    if command -v cygpath >/dev/null 2>&1; then
        PWSH_ROOT=$(cygpath -w "$ROOT")
    else
        PWSH_ROOT="$ROOT"
    fi
    COMPLETER_TEST_ROOT="$PWSH_ROOT" pwsh -NoLogo -NoProfile -Command '
      $e = $null
      $f = Join-Path $env:COMPLETER_TEST_ROOT "completer.ps1"
      [System.Management.Automation.Language.Parser]::ParseFile($f,[ref]$null,[ref]$e) | Out-Null
      if ($e) { exit 1 } else { exit 0 }' \
      && pass "pwsh parse completer.ps1" || fail "pwsh parse completer.ps1"
fi
if command -v nu >/dev/null 2>&1; then
    XDG_CONFIG_HOME="$ROOT/.nu-test-config" nu --no-config-file -c \
      "source '$ROOT/completer.nu'" >/dev/null 2>&1 \
      && pass "nu source completer.nu" || fail "nu source completer.nu"
fi
if command -v xonsh >/dev/null 2>&1; then
    xonsh -c "source '$ROOT/completer.xsh'" >/dev/null 2>&1 \
      && pass "xonsh source completer.xsh" || fail "xonsh source completer.xsh"
fi

echo "== result =="
if [ "$FAIL" -eq 0 ]; then echo "ALL TESTS PASSED"; exit 0; fi
echo "$FAIL TEST(S) FAILED"; exit 1

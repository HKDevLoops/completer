#!/usr/bin/env bash
# Functional tests: actually INVOKE the completer functions in an isolated root.
# Called by run-tests.sh. Uses only native bash + coreutils.
set -u
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FAIL=0
pass() { printf '  ok   %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }

echo "== functional checks (bash, isolated root) =="
TMP=$(mktemp -d 2>/dev/null || printf '/tmp/completer-func-%s' "$$")
mkdir -p "$TMP/home" "$TMP/root/bin"
cat > "$TMP/root/bin/fakeprog" <<'EOF'
#!/bin/sh
printf '%s\n' '__fake_completion_value__'
EOF
chmod +x "$TMP/root/bin/fakeprog"

HOME="$TMP/home" COMPLETER_ROOT="$TMP/root" PATH="$TMP/root/bin:$PATH" \
bash -c '
  . "$1/completer.bash"

  # 1. alias add -> remove must be idempotent and leave exactly one definition.
  completer alias add __probe x >/dev/null
  grep -q "__probe" "$COMPLETER_ROOT/alias.bash" || exit 11
  completer alias add __probe y >/dev/null
  [ "$(grep -c "__probe" "$COMPLETER_ROOT/alias.bash")" -eq 1 ] || exit 12
  completer alias remove __probe >/dev/null
  ! grep -q "__probe" "$COMPLETER_ROOT/alias.bash" || exit 13

  # 2. generation must be idempotent: two runs -> exactly one marker pair.
  completer bash fakeprog >/dev/null || exit 21
  completer bash fakeprog >/dev/null || exit 22
  out="$COMPLETER_ROOT/completions/bash-fakeprog-completion.bash"
  [ "$(grep -c ">>> completer:fakeprog:bash generated" "$out")" -eq 1 ] || exit 23
  [ "$(grep -c "<<< completer:fakeprog:bash <<<" "$out")" -eq 1 ] || exit 24
  grep -q "__fake_completion_value__" "$out" || exit 25

  # 3. list must succeed and report the generated file.
  completer list | grep -q "bash-fakeprog-completion" || exit 31

  # 4. alias values containing shell metacharacters must be rejected so the
  #    generated alias.<ext> cannot execute code when sourced next launch.
  #    Build the payload with printf so no literal quote breaks this script.
  evil=$(printf "x\047; echo PWNED; #")
  completer alias add __evil "$evil" >/dev/null 2>&1 || :
  if grep -q PWNED "$COMPLETER_ROOT/alias.bash" 2>/dev/null; then exit 41; fi

  # 5. self-completion for `completer` must be registered lazily (not at load).
  complete -p completer 2>/dev/null | grep -q _completer_self_complete || exit 51
' _ "$ROOT"
rc=$?
case "$rc" in
  0) pass "bash functional: alias add/remove + idempotent generation + list" ;;
  *) fail "bash functional failed (rc=$rc)" ;;
esac

# Cleanup only our own temp dir.
rm -rf -- "$TMP"

if [ "$FAIL" -eq 0 ]; then echo "FUNCTIONAL TESTS PASSED"; exit 0; fi
echo "$FAIL FUNCTIONAL TEST(S) FAILED"; exit 1

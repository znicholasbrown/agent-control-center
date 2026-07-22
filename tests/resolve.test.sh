#!/usr/bin/env bash
# Tests for bin/resolve — the contextual control-center resolver.
# Builds a sandbox under .tmp/ with a fake HOME and fake centers, then
# checks what resolve prints from different working directories.
# Run: tests/resolve.test.sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOLVE="$ROOT/bin/resolve"

TMP="$ROOT/.tmp/resolve-test.$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

HOME_DIR="$TMP/home"
CFG="$HOME_DIR/.config/agent-control-center"
mkdir -p "$CFG/centers"

# Registered center "alpha" holding a template clone under a project's
# code/ tree. The clone ships its own .control-center file.
ALPHA="$TMP/alpha"
CLONE="$ALPHA/projects/demo/code/agent-control-center/main"
mkdir -p "$CLONE"
echo "name=alpha" >"$ALPHA/.control-center"
echo "name=default" >"$CLONE/.control-center"

# Registered center "beta" — the machine default.
BETA="$TMP/beta"
mkdir -p "$BETA"
echo "name=beta" >"$BETA/.control-center"

echo "$ALPHA" >"$CFG/centers/alpha"
echo "$BETA" >"$CFG/centers/beta"
echo "beta" >"$CFG/default"

# A checkout with .control-center that is not registered and has no
# registered ancestor (a fresh, un-bootstrapped template clone).
STRAY="$TMP/stray"
mkdir -p "$STRAY/sub"
echo "name=default" >"$STRAY/.control-center"

fail=0
check() {
  local name="$1" cwd="$2" expected="$3" got
  got="$(cd "$cwd" && HOME="$HOME_DIR" "$RESOLVE" 2>/dev/null)"
  if [ "$got" = "$expected" ]; then
    echo "  ok      $name"
  else
    echo "  FAIL    $name"
    echo "          expected: $expected"
    echo "          got:      ${got:-<nothing>}"
    fail=1
  fi
}

check "registered center resolves to itself" "$ALPHA/projects/demo" "$ALPHA"
check "template clone under code/ resolves to the enclosing center" "$CLONE" "$ALPHA"
check "no registered ancestor falls back to the default center" "$STRAY/sub" "$BETA"

# No default configured and no registered ancestor: fail loudly.
rm "$CFG/default"
if (cd "$STRAY" && HOME="$HOME_DIR" "$RESOLVE" >/dev/null 2>&1); then
  echo "  FAIL    no default and no registered ancestor exits non-zero"
  fail=1
else
  echo "  ok      no default and no registered ancestor exits non-zero"
fi

exit $fail

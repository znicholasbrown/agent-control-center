#!/usr/bin/env bash
# Tests for permission-prompt avoidance: skills must not use the
# CC=$(...) idiom (allow rules cannot match past an assignment), and
# link.sh must merge allow rules into ~/.claude/settings.json.
# Run: tests/link.test.sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$ROOT/.tmp/link-test.$$"
trap 'rm -rf "$TMP"' EXIT
fail=0

# --- skills run the resolver bare -----------------------------------------
if grep -rn 'CC=\$(' "$ROOT/skills/" >/dev/null 2>&1; then
  echo "  FAIL    skills contain no CC=\$() idiom"
  grep -rn 'CC=\$(' "$ROOT/skills/" | sed 's/^/          /'
  fail=1
else
  echo "  ok      skills contain no CC=\$() idiom"
fi

# --- link.sh merges allow rules (sandbox HOME) ----------------------------
command -v jq >/dev/null 2>&1 || { echo "  SKIP    jq missing"; exit $fail; }

CENTER="$TMP/center"
HOMEDIR="$TMP/home"
mkdir -p "$CENTER/bin" "$CENTER/skills/dummy" "$HOMEDIR/.claude"
cp "$ROOT/bin/link.sh" "$CENTER/bin/link.sh"
cp "$ROOT/bin/resolve" "$CENTER/bin/resolve"
echo "name=testcenter" >"$CENTER/.control-center"
: >"$CENTER/skills/dummy/SKILL.md"
echo '{"permissions":{"allow":["Bash(echo preserved)"]}}' \
  >"$HOMEDIR/.claude/settings.json"

if ! HOME="$HOMEDIR" "$CENTER/bin/link.sh" --default >/dev/null 2>&1; then
  echo "  FAIL    link.sh exits 0 in sandbox"
  exit 1
fi
S="$HOMEDIR/.claude/settings.json"

want() {
  if jq -e --arg r "$1" '.permissions.allow | index($r)' "$S" >/dev/null; then
    echo "  ok      allow: $1"
  else
    echo "  FAIL    allow: $1"
    fail=1
  fi
}
want "Bash(~/.config/agent-control-center/resolve)"
want "Bash(~/.config/agent-control-center/resolve *)"
want "Bash($CENTER/bin/wt-ls)"
want "Bash($CENTER/bin/wt-ls *)"
want "Bash($CENTER/bin/wt-new *)"
want "Bash($CENTER/bin/wt-prune)"
want "Bash($CENTER/bin/sync.sh pull)"
want "Bash(echo preserved)"

# never allowlist the mutating forms
for bad in "Bash($CENTER/bin/wt-prune --apply)" "Bash($CENTER/bin/wt-prune *)" \
           "Bash($CENTER/bin/sync.sh push)" "Bash($CENTER/bin/sync.sh *)"; do
  if jq -e --arg r "$bad" '.permissions.allow | index($r)' "$S" >/dev/null; then
    echo "  FAIL    absent: $bad"
    fail=1
  else
    echo "  ok      absent: $bad"
  fi
done

# --- idempotent: second run adds no duplicates ----------------------------
n1="$(jq '.permissions.allow | length' "$S")"
HOME="$HOMEDIR" "$CENTER/bin/link.sh" --default >/dev/null 2>&1
n2="$(jq '.permissions.allow | length' "$S")"
if [ "$n1" = "$n2" ]; then
  echo "  ok      idempotent allow merge ($n1 rules)"
else
  echo "  FAIL    idempotent allow merge ($n1 -> $n2)"
  fail=1
fi

exit $fail

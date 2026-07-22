#!/usr/bin/env bash
# Tests for bin/wt-new branch setup.
# Builds a sandbox center with a local bare remote and checks that a
# fresh task worktree gets a branch with NO upstream. With no upstream,
# a user's push.autoSetupRemote makes the first `git push` create the
# same-name remote branch; an inherited origin/main upstream makes
# `git push` fail under push.default=simple.
# Run: tests/wt-new.test.sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$ROOT/.tmp/wt-new-test.$$"
CENTER="$TMP/center"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$CENTER/bin" "$CENTER/templates" "$CENTER/projects/demo/code"
cp "$ROOT/bin/wt-new" "$CENTER/bin/wt-new"
cp "$ROOT/templates/handoff.md" "$CENTER/templates/handoff.md"
: >"$CENTER/projects/demo/PROJECT.md"

git init -q --bare -b main "$TMP/remote.git"
git init -q -b main "$TMP/seed"
(cd "$TMP/seed" &&
  echo x >file &&
  git add file &&
  git -c user.name=t -c user.email=t@t commit -qm seed &&
  git push -q "$TMP/remote.git" main)
git clone -q "$TMP/remote.git" "$CENTER/projects/demo/code/repo/main"

fail=0
if ! "$CENTER/bin/wt-new" repo task-x --project demo >/dev/null 2>&1; then
  echo "  FAIL    wt-new exited non-zero"
  exit 1
fi

WT="$CENTER/projects/demo/code/repo/task-x"
if [ -d "$WT" ]; then
  echo "  ok      worktree created"
else
  echo "  FAIL    worktree created"
  fail=1
fi

upstream="$(git -C "$WT" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
if [ -z "$upstream" ]; then
  echo "  ok      fresh task branch has no upstream"
else
  echo "  FAIL    fresh task branch has no upstream (got: $upstream)"
  fail=1
fi

# --- template has no binding placeholders ---------------------------------
if grep -qE '\{\{(REPO_NAME|BRANCH)\}\}' "$ROOT/templates/handoff.md"; then
  echo "  FAIL    template has no binding placeholders"
  fail=1
else
  echo "  ok      template has no binding placeholders"
fi

# --- fresh handoff gets the binding ---------------------------------------
H1="$CENTER/projects/demo/handoffs/task-x.md"
if grep -q '^repo: repo$' "$H1" &&
   grep -q '^branch: task-x$' "$H1" &&
   grep -q '^worktree: code/repo/task-x$' "$H1"; then
  echo "  ok      fresh handoff bound"
else
  echo "  FAIL    fresh handoff bound"
  fail=1
fi

# --- pre-existing unbound handoff gains binding, body preserved -----------
H2="$CENTER/projects/demo/handoffs/task-y.md"
cat >"$H2" <<'EOF'
---
task: task-y
project: demo
status: active
updated: 2026-01-01
---

# task-y

Body line to preserve.
EOF
body_before="$(awk '/^---$/{f++; next} f>=2' "$H2")"
"$CENTER/bin/wt-new" repo task-y --project demo >/dev/null 2>&1
body_after="$(awk '/^---$/{f++; next} f>=2' "$H2")"
if grep -q '^worktree: code/repo/task-y$' "$H2" &&
   grep -q '^repo: repo$' "$H2" &&
   [ "$body_before" = "$body_after" ]; then
  echo "  ok      unbound handoff gains binding, body preserved"
else
  echo "  FAIL    unbound handoff gains binding, body preserved"
  fail=1
fi

# --- legacy 'worktree: none' handoff is healed ----------------------------
H3="$CENTER/projects/demo/handoffs/task-z.md"
cat >"$H3" <<'EOF'
---
task: task-z
project: demo
repo: repo
branch: none
worktree: none
status: active
updated: 2026-01-01
---

# task-z
EOF
"$CENTER/bin/wt-new" repo task-z --project demo >/dev/null 2>&1
if grep -q '^worktree: code/repo/task-z$' "$H3" &&
   grep -q '^branch: task-z$' "$H3" &&
   ! grep -q ': none$' "$H3"; then
  echo "  ok      legacy none binding healed"
else
  echo "  FAIL    legacy none binding healed"
  fail=1
fi

# --- foreign binding is never clobbered -----------------------------------
H4="$CENTER/projects/demo/handoffs/task-w.md"
cat >"$H4" <<'EOF'
---
task: task-w
project: demo
repo: repo
branch: other-branch
worktree: code/repo/other-task
status: active
updated: 2026-01-01
---

# task-w
EOF
cp "$H4" "$H4.orig"
if "$CENTER/bin/wt-new" repo task-w --project demo >/dev/null 2>"$TMP/task-w.err" &&
   cmp -s "$H4" "$H4.orig" &&
   grep -q "bound to" "$TMP/task-w.err"; then
  echo "  ok      foreign binding untouched, warns, exits 0"
else
  echo "  FAIL    foreign binding untouched, warns, exits 0"
  fail=1
fi

exit $fail

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

exit $fail

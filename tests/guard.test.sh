#!/usr/bin/env bash
# Tests for bin/guard-path.sh bash-mode scanning.
# Builds a sandbox center under .tmp/ with git-inited fake worktrees
# and copies the guard into it (the guard derives CC_ROOT from its own
# location). Checks allow/deny verdicts for bash commands.
# Run: tests/guard.test.sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$ROOT/.tmp/guard-test.$$"
CENTER="$TMP/center"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$CENTER/bin" "$CENTER/projects/demo/code/repo"
cp "$ROOT/bin/guard-path.sh" "$CENTER/bin/guard-path.sh"
GUARD="$CENTER/bin/guard-path.sh"

for wt in main task-a task-b; do
  git init -q "$CENTER/projects/demo/code/repo/$wt" 2>/dev/null
done

TASK_A="$CENTER/projects/demo/code/repo/task-a"
PROJ="$CENTER/projects/demo"

fail=0
verdict() {
  local expected="$1" name="$2" cwd="$3" cmd="$4" rc got
  "$GUARD" bash "$cwd" "$cmd" >/dev/null 2>&1
  rc=$?
  case "$rc" in
    0) got=allow ;;
    2) got=deny ;;
    *) got="exit $rc" ;;
  esac
  if [ "$got" = "$expected" ]; then
    echo "  ok      $name"
  else
    echo "  FAIL    $name (expected $expected, got $got)"
    fail=1
  fi
}

verdict allow "own worktree read"               "$TASK_A" "cat src/x"
verdict allow "own worktree write"              "$TASK_A" "sed -i s/a/b/ src/x"
verdict deny  "sibling worktree read, relative" "$TASK_A" "cat ../task-b/file"
verdict allow "main read, relative"             "$TASK_A" "cat ../main/file"
verdict deny  "main write via sed -i"           "$TASK_A" "sed -i s/a/b/ ../main/file"
verdict deny  "main write via redirect"         "$TASK_A" "echo x > ../main/notes.txt"
verdict allow "own worktree redirect"           "$TASK_A" "echo x > notes.txt"
verdict allow "git pull on main"                "$TASK_A" "git -C ../main pull"
verdict allow "cd to worktree root, relative"   "$PROJ" "cd code/repo/task-a && git log"
verdict allow "cd to worktree root, absolute"   "$PROJ" "cd $TASK_A && git log"
verdict deny  "deep foreign path, relative"     "$PROJ" "cat code/repo/task-a/src/x"
verdict deny  "deep foreign path, absolute"     "$PROJ" "cat $CENTER/projects/demo/code/repo/task-b/f"
verdict deny  "git clean -x at center root"     "$CENTER" "git clean -dfx"
verdict deny  "quoted relative path"            "$PROJ" "cat 'code/repo/task-a/src/x'"
verdict allow "unparseable command fails open"  "$TASK_A" "cat \"../task-b/file"

exit $fail

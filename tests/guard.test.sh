#!/usr/bin/env bash
# Tests for bin/guard-path.sh project-scoped enforcement.
# Builds a sandbox center under .tmp/ with git-inited fake worktrees in
# two projects and checks allow/deny verdicts for read, write, and bash
# modes. The guard derives CC_ROOT from its own location.
# Run: tests/guard.test.sh
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$ROOT/.tmp/guard-test.$$"
CENTER="$TMP/center"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$CENTER/bin"
cp "$ROOT/bin/guard-path.sh" "$CENTER/bin/guard-path.sh"
GUARD="$CENTER/bin/guard-path.sh"

for wt in \
  projects/demo/code/repo/main \
  projects/demo/code/repo/task-a \
  projects/demo/code/repo/task-b \
  projects/demo/code/repo2/task-c \
  projects/other/code/x/main \
  projects/other/code/x/task-d; do
  mkdir -p "$CENTER/$wt"
  git init -q "$CENTER/$wt" 2>/dev/null
done

DEMO="$CENTER/projects/demo"
OTHER="$CENTER/projects/other"
TASK_A="$DEMO/code/repo/task-a"

fail=0
run() {  # expected name mode cwd target
  local expected="$1" name="$2" mode="$3" cwd="$4" target="$5" rc got
  "$GUARD" "$mode" "$cwd" "$target" >/dev/null 2>&1
  rc=$?
  case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit $rc" ;; esac
  if [ "$got" = "$expected" ]; then echo "  ok      $name"
  else echo "  FAIL    $name (expected $expected, got $got)"; fail=1; fi
}

# --- read / write mode: project-scoped ---
run allow "write own project task-a"            write "$DEMO"   "$DEMO/code/repo/task-a/f"
run allow "write own project second repo"       write "$DEMO"   "$DEMO/code/repo2/task-c/f"
run deny  "write own project main"              write "$DEMO"   "$DEMO/code/repo/main/f"
run allow "read own project main"               read  "$DEMO"   "$DEMO/code/repo/main/f"
run allow "read sibling task-b"                 read  "$DEMO"   "$DEMO/code/repo/task-b/f"
run deny  "write cross-project"                 write "$DEMO"   "$OTHER/code/x/task-d/f"
run deny  "read cross-project task"             read  "$DEMO"   "$OTHER/code/x/task-d/f"
run allow "read cross-project main"             read  "$DEMO"   "$OTHER/code/x/main/f"
run deny  "write from center root"              write "$CENTER" "$DEMO/code/repo/task-a/f"
run allow "read main from center root"          read  "$CENTER" "$DEMO/code/repo/main/f"
run allow "write from inside worktree, sibling" write "$TASK_A" "$DEMO/code/repo/task-b/f"

# --- bash mode ---
run allow "bash write own project, relative"    bash "$DEMO"    "sed -i s/a/b/ code/repo/task-a/f"
run deny  "bash write cross-project, relative"   bash "$DEMO"    "sed -i s/a/b/ ../other/code/x/task-d/f"
run deny  "bash write main, relative"            bash "$DEMO"    "sed -i s/a/b/ code/repo/main/f"
run allow "bash read own worktree"               bash "$TASK_A"  "cat src/x"
run allow "bash git pull on main"                bash "$TASK_A"  "git -C ../main pull"
run deny  "bash git clean -x at center root"      bash "$CENTER"  "git clean -dfx"
run allow "bash unparseable fails open"           bash "$TASK_A"  "cat \"../task-b/file"

exit $fail

#!/usr/bin/env bash
# guard-path.sh — blocks file operations that cross into a foreign worktree.
#
# Usage: guard-path.sh <mode> <cwd> <target>
#   mode:   read | write | bash
#   cwd:    the session's working directory
#   target: a file path (read/write) or a full command string (bash)
#
# Exit 0 = allow. Exit 2 = deny, with the reason on stderr (agent-visible).
# Set CC_GUARD_DISABLE=1 to bypass.
set -u

[ "${CC_GUARD_DISABLE:-0}" = "1" ] && exit 0

MODE="${1:-}"; CWD="${2:-}"; TARGET="${3:-}"
[ -z "$MODE" ] || [ -z "$CWD" ] || [ -z "$TARGET" ] && exit 0

CC_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CODE_RE="^$CC_ROOT/projects/[^/]+/code(/|$)"

deny() {
  echo "BLOCKED by control-center guard: $1" >&2
  exit 2
}

# Resolve a path (which may not exist yet) to an absolute, symlink-free form.
resolve() {
  local p="$1"
  case "$p" in
    /*) : ;;
    ~*) p="${p/#\~/$HOME}" ;;
    *) p="$CWD/$p" ;;
  esac
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$p"
  else
    echo "$p"
  fi
}

WS="$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || true)"

# Check one absolute path under the given mode. Allows anything outside
# projects/*/code/; inside it, only the session's own worktree is writable
# and only <repo>/main is readable as a reference.
check_path() {
  local mode="$1" abs="$2"
  echo "$abs" | grep -qE "$CODE_RE" || return 0

  local rel proj repo wt tree
  rel="${abs#"$CC_ROOT"/projects/}"
  proj="${rel%%/*}"
  rel="${rel#"$proj"/code}"
  rel="${rel#/}"
  repo="${rel%%/*}"
  rel="${rel#"$repo"}"
  rel="${rel#/}"
  wt="${rel%%/*}"

  # Path at or above the worktree level (e.g. listing code/<repo>/).
  if [ -z "$repo" ] || [ -z "$wt" ]; then
    [ "$mode" = "write" ] && deny "cannot write at $abs — writes must target files inside your own worktree (workspace: ${WS:-unknown})."
    return 0
  fi

  tree="$CC_ROOT/projects/$proj/code/$repo/$wt"
  [ "$tree" = "$WS" ] && return 0

  if [ "$mode" != "write" ] && [ "$wt" = "main" ]; then
    return 0  # main is a read-only reference checkout
  fi

  deny "$abs is inside the worktree '$proj/code/$repo/$wt', but your workspace is '${WS:-not a worktree}'. Work only inside your own worktree; read code/$repo/main for reference. If you need a worktree for this task, run bin/wt-new."
}

case "$MODE" in
  read|write)
    check_path "$MODE" "$(resolve "$TARGET")"
    ;;
  bash)
    # Refuse `git clean` with -x style flags anywhere near the control center:
    # it would delete every ignored code/ checkout.
    if echo "$TARGET" | grep -qE 'git[^|;&]*clean[^|;&]*-[a-zA-Z]*[xX]'; then
      case "$CWD" in "$CC_ROOT"*) deny "'git clean -x' under the control center deletes every project's code/ checkouts. Never run it here." ;; esac
      echo "$TARGET" | grep -q "$CC_ROOT" && deny "'git clean -x' targeting the control center deletes every project's code/ checkouts. Never run it."
    fi
    # Scan the command for absolute paths into any code/ tree; vet each as a read.
    for p in $(echo "$TARGET" | grep -oE "$CC_ROOT/projects/[^/]+/code/[^ '\"\`;|&)]*" | sort -u); do
      check_path read "$(resolve "$p")"
    done
    ;;
  *)
    exit 0
    ;;
esac

exit 0

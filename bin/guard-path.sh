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

  if [ "$mode" != "write" ] && [ "$abs" = "$tree" ]; then
    return 0  # the worktree root itself: cd rebinds and listings are fine
  fi

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
    # Tokenize the command: resolve path-like tokens (relative included)
    # against CWD and classify each as read or write from the command
    # shape. Falls back to the absolute-substring scan below when
    # python3 is missing or the command has no path-like content.
    if command -v python3 >/dev/null 2>&1; then
      case "$TARGET" in
        */*|*..*)
          scan="$(printf '%s' "$TARGET" | python3 -c '
import os, re, shlex, sys
cwd = sys.argv[1]
try:
    lex = shlex.shlex(sys.stdin.read(), posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    toks = list(lex)
except ValueError:
    sys.exit(0)
punct = set("();<>|&")
def op(t):
    return bool(t) and all(c in punct for c in t)
wrap = {"sudo", "env", "command", "nohup", "time", "xargs"}
mut = {"rm", "mv", "cp", "tee", "touch", "mkdir", "rmdir", "chmod",
       "chown", "ln", "truncate", "rsync", "install"}
assign = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
segs, cur = [], []
for t in toks:
    if op(t) and ">" not in t and "<" not in t:
        if cur:
            segs.append(cur)
        cur = []
    else:
        cur.append(t)
if cur:
    segs.append(cur)
def cands(t):
    forms = [t]
    if "=" in t:
        forms.append(t.split("=", 1)[1])
    return [s for s in forms if "/" in s or s == ".."]
seen = []
for seg in segs:
    words = [t for t in seg if not op(t)]
    name = ""
    for w in words:
        if assign.match(w) or os.path.basename(w) in wrap:
            continue
        name = os.path.basename(w)
        break
    mode = "write" if name in mut else "read"
    if name in ("sed", "perl") and any(w.startswith("-i") or w == "--in-place" for w in words):
        mode = "write"
    redir = False
    for t in seg:
        if op(t):
            redir = ">" in t
            continue
        tmode = "write" if redir else mode
        redir = False
        for s in cands(t):
            p = os.path.realpath(os.path.join(cwd, os.path.expanduser(s)))
            if (tmode, p) not in seen:
                seen.append((tmode, p))
for tmode, p in seen:
    sys.stdout.write(tmode + "\t" + p + "\n")
' "$CWD" 2>/dev/null || true)"
          while IFS=$'\t' read -r tmode tpath; do
            [ -n "$tpath" ] && check_path "$tmode" "$tpath"
          done <<<"$scan"
          ;;
      esac
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

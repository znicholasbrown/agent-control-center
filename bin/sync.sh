#!/usr/bin/env bash
# sync.sh — keeps control-center docs current with the remote.
#
# Usage: sync.sh pull | push
#   pull: rebase-pull the control center (run at session start)
#   push: commit projects/ + memory/ docs and push (run at session end)
#
# Only ever commits paths under projects/ and memory/ (code/ is gitignored
# and can never be committed). Never touches repos under code/.
# Always exits 0 so a sync problem never breaks an agent session; problems
# are logged to .sync.log and printed to stderr.
set -u

CC_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-}"
LOCK="$CC_ROOT/.sync.lock"
LOG="$CC_ROOT/.sync.log"

note() { echo "sync: $1" >&2; echo "$(date '+%F %T') $1" >>"$LOG"; }

git -C "$CC_ROOT" rev-parse --git-dir >/dev/null 2>&1 || exit 0
git -C "$CC_ROOT" remote get-url origin >/dev/null 2>&1 || exit 0

# One sync at a time; a stale lock (>10 min) is reclaimed.
if ! mkdir "$LOCK" 2>/dev/null; then
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +10 2>/dev/null)" ]; then
    rmdir "$LOCK" 2>/dev/null
    mkdir "$LOCK" 2>/dev/null || exit 0
  else
    exit 0
  fi
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

remote_has_main() {
  git -C "$CC_ROOT" ls-remote --exit-code --heads origin main >/dev/null 2>&1
}

do_pull() {
  remote_has_main || return 0
  if ! git -C "$CC_ROOT" pull --rebase --autostash --quiet origin main 2>>"$LOG"; then
    git -C "$CC_ROOT" rebase --abort >/dev/null 2>&1
    note "PULL FAILED — resolve manually in $CC_ROOT (see .sync.log)"
  fi
}

do_push() {
  git -C "$CC_ROOT" add -A -- projects memory 2>>"$LOG"
  if ! git -C "$CC_ROOT" diff --cached --quiet; then
    git -C "$CC_ROOT" commit --quiet \
      -m "sync($(hostname -s)): $(date '+%F %T')" 2>>"$LOG" \
      || { note "COMMIT FAILED (see .sync.log)"; return 0; }
  fi
  do_pull
  if ! git -C "$CC_ROOT" push --quiet origin main 2>>"$LOG"; then
    note "PUSH FAILED — will retry next session (see .sync.log)"
  fi
}

case "$MODE" in
  pull) do_pull ;;
  push) do_push ;;
  *) echo "usage: sync.sh pull|push" >&2 ;;
esac

exit 0

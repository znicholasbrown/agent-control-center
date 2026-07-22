#!/usr/bin/env bash
# bootstrap.sh — one-time setup on a new machine (idempotent, safe to re-run).
# Checks dependencies, then registers and wires this control center into
# the installed agent CLIs via link.sh.
#
# Usage: bootstrap.sh [--name <name>] [--default]
#   --name     set this center's name (written to .control-center);
#              required when running a second center from the template,
#              since names must be unique per machine
#   --default  make this center the machine default
set -euo pipefail

CC_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

NAME_ARG=""
DEFAULT_FLAG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME_ARG="${2:-}"; shift 2 ;;
    --default) DEFAULT_FLAG="--default"; shift ;;
    *) echo "usage: bootstrap.sh [--name <name>] [--default]" >&2; exit 1 ;;
  esac
done

if [ -n "$NAME_ARG" ]; then
  {
    echo "# Identity of this control center. The name registers this checkout in"
    echo "# ~/.config/agent-control-center/centers/ and must be unique per machine."
    echo "# Set it with: ./bin/bootstrap.sh --name <name>"
    echo "name=$NAME_ARG"
  } >"$CC_ROOT/.control-center"
  echo "named this center: $NAME_ARG"
fi

echo "agent-control-center bootstrap"
echo "root: $CC_ROOT"
echo ""

missing=0
need() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "  ok      $1"
  else
    echo "  MISSING $1 — $2"
    missing=1
  fi
}

echo "dependencies:"
need git "required"
need jq "required for Claude Code hook wiring (brew install jq)"
need python3 "used by the path guard to resolve paths (falls back without it)"
echo ""

echo "agent CLIs detected:"
command -v claude >/dev/null 2>&1 && echo "  claude ($(command -v claude))"
command -v opencode >/dev/null 2>&1 && echo "  opencode ($(command -v opencode))"
echo ""

"$CC_ROOT/bin/link.sh" $DEFAULT_FLAG

echo ""
echo "next steps:"
echo "  - restart any running agent sessions so hooks take effect"
echo "  - optional: install a launchd sync fallback (see README)"
echo "  - start or resume work: /start-project or /resume-project"
[ "$missing" = 1 ] && echo "  - install missing dependencies above, then re-run this script"
exit 0

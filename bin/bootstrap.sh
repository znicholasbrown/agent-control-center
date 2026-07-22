#!/usr/bin/env bash
# bootstrap.sh — one-time setup on a new machine (idempotent, safe to re-run).
# Checks dependencies, then wires the control center into the installed
# agent CLIs via link.sh.
set -euo pipefail

CC_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

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

"$CC_ROOT/bin/link.sh"

echo ""
echo "next steps:"
echo "  - restart any running agent sessions so hooks take effect"
echo "  - optional: install a launchd sync fallback (see README)"
echo "  - start or resume work: /start-project or /resume-project"
[ "$missing" = 1 ] && echo "  - install missing dependencies above, then re-run this script"
exit 0

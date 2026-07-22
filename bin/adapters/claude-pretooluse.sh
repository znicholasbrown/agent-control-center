#!/usr/bin/env bash
# Claude Code PreToolUse adapter for guard-path.sh.
# Reads the hook JSON from stdin, maps the tool to a guard mode, and
# delegates. Exit 2 from the guard blocks the tool call; its stderr is
# shown to the model so it can self-correct.
set -u

GUARD="$(cd "$(dirname "$0")/.." && pwd)/guard-path.sh"
command -v jq >/dev/null 2>&1 || exit 0
[ -x "$GUARD" ] || exit 0

input="$(cat)"
tool="$(jq -r '.tool_name // empty' <<<"$input")"
cwd="$(jq -r '.cwd // empty' <<<"$input")"

case "$tool" in
  Read|Grep|Glob)
    mode=read
    target="$(jq -r '.tool_input.file_path // .tool_input.path // empty' <<<"$input")"
    ;;
  Edit|Write|MultiEdit)
    mode=write
    target="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
    ;;
  NotebookEdit)
    mode=write
    target="$(jq -r '.tool_input.notebook_path // empty' <<<"$input")"
    ;;
  Bash)
    mode=bash
    target="$(jq -r '.tool_input.command // empty' <<<"$input")"
    ;;
  *) exit 0 ;;
esac

[ -z "$target" ] && exit 0
exec "$GUARD" "$mode" "${cwd:-$PWD}" "$target"

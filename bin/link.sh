#!/usr/bin/env bash
# link.sh — wires the control center into each agent CLI. Idempotent.
#
#   Claude Code:  import line in ~/.claude/CLAUDE.md, skill symlinks,
#                 guard + sync hooks merged into ~/.claude/settings.json
#   opencode:     global AGENTS.md symlink, guard plugin symlink,
#                 command shims for the lifecycle skills
#
# Run via bootstrap.sh, or directly after adding a skill.
set -euo pipefail

CC_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
say() { echo "link: $1"; }

# ---- Claude Code: global import -------------------------------------------
CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
IMPORT_LINE="@$CC_ROOT/AGENTS.md"
mkdir -p "$CLAUDE_DIR"
touch "$CLAUDE_MD"
if ! grep -qxF "$IMPORT_LINE" "$CLAUDE_MD"; then
  printf "\n# agent-control-center (managed by link.sh)\n%s\n" "$IMPORT_LINE" >>"$CLAUDE_MD"
  say "added control-center import to ~/.claude/CLAUDE.md"
else
  say "~/.claude/CLAUDE.md import already present"
fi

# ---- Claude Code: skills ---------------------------------------------------
mkdir -p "$CLAUDE_DIR/skills"
for skill_dir in "$CC_ROOT"/skills/*/; do
  name="$(basename "$skill_dir")"
  dest="$CLAUDE_DIR/skills/$name"
  if [ -L "$dest" ] || [ ! -e "$dest" ]; then
    ln -sfn "${skill_dir%/}" "$dest"
    say "skill linked: $name"
  else
    say "SKIPPED skill $name — $dest exists and is not a symlink"
  fi
done

# ---- Claude Code: hooks ----------------------------------------------------
SETTINGS="$CLAUDE_DIR/settings.json"
if command -v jq >/dev/null 2>&1; then
  [ -f "$SETTINGS" ] || echo '{}' >"$SETTINGS"
  cp "$SETTINGS" "$SETTINGS.bak"
  jq --arg cc "$CC_ROOT" '
    def strip_ours: map(select((tojson | contains("agent-control-center")) | not));
    .hooks //= {} |
    .hooks.PreToolUse = ((.hooks.PreToolUse // []) | strip_ours) + [{
      matcher: "Read|Grep|Glob|Edit|Write|MultiEdit|NotebookEdit|Bash",
      hooks: [{type: "command", command: ($cc + "/bin/adapters/claude-pretooluse.sh")}]
    }] |
    .hooks.SessionStart = ((.hooks.SessionStart // []) | strip_ours) + [{
      hooks: [{type: "command", command: ($cc + "/bin/sync.sh pull")}]
    }] |
    .hooks.SessionEnd = ((.hooks.SessionEnd // []) | strip_ours) + [{
      hooks: [{type: "command", command: ($cc + "/bin/sync.sh push")}]
    }]
  ' "$SETTINGS.bak" >"$SETTINGS"
  say "hooks merged into ~/.claude/settings.json (backup: settings.json.bak)"
else
  say "SKIPPED hooks — jq not installed (brew install jq, then re-run)"
fi

# ---- opencode: global rules ------------------------------------------------
OC_DIR="$HOME/.config/opencode"
mkdir -p "$OC_DIR"
if [ -L "$OC_DIR/AGENTS.md" ] || [ ! -e "$OC_DIR/AGENTS.md" ]; then
  ln -sfn "$CC_ROOT/AGENTS.md" "$OC_DIR/AGENTS.md"
  say "opencode global AGENTS.md linked"
else
  say "SKIPPED opencode AGENTS.md — real file exists; merge it manually"
fi

# ---- opencode: guard plugin ------------------------------------------------
mkdir -p "$OC_DIR/plugin"
ln -sfn "$CC_ROOT/bin/adapters/opencode-control-center.js" \
  "$OC_DIR/plugin/opencode-control-center.js"
say "opencode guard plugin linked"

# ---- opencode: lifecycle command shims ------------------------------------
mkdir -p "$OC_DIR/command"
for skill_dir in "$CC_ROOT"/skills/*/; do
  name="$(basename "$skill_dir")"
  cat >"$OC_DIR/command/$name.md" <<EOF
---
description: Control-center lifecycle: $name
---
Read $CC_ROOT/skills/$name/SKILL.md and follow it exactly.
EOF
done
say "opencode command shims written"

say "done"

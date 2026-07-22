#!/usr/bin/env bash
# link.sh — registers this control center and wires it into agent CLIs.
# Idempotent; safe to re-run from any center at any time.
#
# Multiple control centers per machine are supported:
#   - each center has a unique name in its .control-center file
#   - all centers are recorded in ~/.config/agent-control-center/centers/
#   - one center is the default, used by sessions outside any center;
#     sessions inside a center resolve it contextually (walk-up)
#   - guard + sync hooks are registered for EVERY center, so each
#     center's worktrees are protected regardless of where you work
#
# Usage: link.sh [--default]
#   --default  make this center the machine default (the first center
#              registered becomes the default automatically)
set -euo pipefail

CC_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CFG="$HOME/.config/agent-control-center"
say() { echo "link: $1"; }

MAKE_DEFAULT=0
case "${1:-}" in
  --default) MAKE_DEFAULT=1 ;;
  "") : ;;
  *) echo "usage: link.sh [--default]" >&2; exit 1 ;;
esac

# ---- Identity --------------------------------------------------------------
if [ ! -f "$CC_ROOT/.control-center" ]; then
  echo "error: $CC_ROOT/.control-center is missing — run bootstrap.sh --name <name>" >&2
  exit 1
fi
NAME="$(sed -n 's/^name=//p' "$CC_ROOT/.control-center" | head -1)"
case "$NAME" in
  ""|*[!a-z0-9-]*)
    echo "error: invalid center name '$NAME' — use lowercase letters, digits, hyphens (bootstrap.sh --name <name>)" >&2
    exit 1
    ;;
esac

# ---- Registry --------------------------------------------------------------
mkdir -p "$CFG/centers"
if [ -f "$CFG/centers/$NAME" ] && [ "$(cat "$CFG/centers/$NAME")" != "$CC_ROOT" ]; then
  echo "error: '$NAME' is already registered to $(cat "$CFG/centers/$NAME")." >&2
  echo "       give this center a unique name: bootstrap.sh --name <other-name>" >&2
  exit 1
fi
echo "$CC_ROOT" >"$CFG/centers/$NAME"

# Prune entries whose checkout no longer exists.
for f in "$CFG/centers"/*; do
  [ -f "$f" ] || continue
  if [ ! -d "$(cat "$f")" ]; then
    say "pruned stale center: $(basename "$f")"
    rm "$f"
  fi
done
rm -f "$CFG/root"  # legacy singleton pointer, superseded by the registry

if [ ! -f "$CFG/default" ] || [ "$MAKE_DEFAULT" = 1 ]; then
  echo "$NAME" >"$CFG/default"
fi
DEFAULT_NAME="$(cat "$CFG/default")"
if [ ! -f "$CFG/centers/$DEFAULT_NAME" ]; then
  echo "$NAME" >"$CFG/default"
  DEFAULT_NAME="$NAME"
fi
DEFAULT_ROOT="$(cat "$CFG/centers/$DEFAULT_NAME")"
say "registered '$NAME' -> $CC_ROOT (default center: $DEFAULT_NAME)"

# ---- Resolver: how skills and humans find the right center ----------------
cat >"$CFG/resolve" <<'EOF'
#!/bin/sh
# Prints the control-center root for the current context: the nearest
# ancestor directory containing a .control-center file, else the
# machine's default center.
d="$PWD"
while [ "$d" != "/" ]; do
  [ -f "$d/.control-center" ] && { echo "$d"; exit 0; }
  d="$(dirname "$d")"
done
cfg="$HOME/.config/agent-control-center"
if [ -f "$cfg/default" ] && [ -f "$cfg/centers/$(cat "$cfg/default")" ]; then
  cat "$cfg/centers/$(cat "$cfg/default")"
  exit 0
fi
echo "no control center found; run bootstrap.sh from a control-center checkout" >&2
exit 1
EOF
chmod +x "$CFG/resolve"

# ---- Claude Code: global import (default center only) ---------------------
CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
MARK="# agent-control-center (managed by link.sh)"
mkdir -p "$CLAUDE_DIR"
touch "$CLAUDE_MD"
awk -v m="$MARK" '$0 == m {skip = 2} skip > 0 {skip--; next} {print}' "$CLAUDE_MD" >"$CLAUDE_MD.tmp"
printf "%s\n@%s/AGENTS.md\n" "$MARK" "$DEFAULT_ROOT" >>"$CLAUDE_MD.tmp"
mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
say "global import in ~/.claude/CLAUDE.md -> $DEFAULT_NAME center"

# ---- Claude Code: skills ---------------------------------------------------
# Skills are center-agnostic (they resolve $CC contextually), so one link
# per skill name serves every center. Last center linked wins.
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

# ---- Claude Code: hooks for EVERY registered center -----------------------
SETTINGS="$CLAUDE_DIR/settings.json"
if command -v jq >/dev/null 2>&1; then
  [ -f "$SETTINGS" ] || echo '{}' >"$SETTINGS"
  cp "$SETTINGS" "$SETTINGS.bak"
  ROOTS_JSON="$(for f in "$CFG/centers"/*; do [ -f "$f" ] && cat "$f"; done | jq -R . | jq -s 'unique')"
  jq --argjson roots "$ROOTS_JSON" '
    def ours: tojson | test("bin/adapters/claude-pretooluse\\.sh|bin/sync\\.sh");
    .hooks //= {} |
    .hooks.PreToolUse = ((.hooks.PreToolUse // []) | map(select(ours | not))) + [$roots[] | {
      matcher: "Read|Grep|Glob|Edit|Write|MultiEdit|NotebookEdit|Bash",
      hooks: [{type: "command", command: (. + "/bin/adapters/claude-pretooluse.sh")}]
    }] |
    .hooks.SessionStart = ((.hooks.SessionStart // []) | map(select(ours | not))) + [$roots[] | {
      hooks: [{type: "command", command: (. + "/bin/sync.sh pull")}]
    }] |
    .hooks.SessionEnd = ((.hooks.SessionEnd // []) | map(select(ours | not))) + [$roots[] | {
      hooks: [{type: "command", command: (. + "/bin/sync.sh push")}]
    }]
  ' "$SETTINGS.bak" >"$SETTINGS"
  say "hooks registered for all centers (backup: settings.json.bak)"
else
  say "SKIPPED hooks — jq not installed (brew install jq, then re-run)"
fi

# ---- opencode: global rules (default center only) -------------------------
OC_DIR="$HOME/.config/opencode"
mkdir -p "$OC_DIR"
if [ -L "$OC_DIR/AGENTS.md" ] || [ ! -e "$OC_DIR/AGENTS.md" ]; then
  ln -sfn "$DEFAULT_ROOT/AGENTS.md" "$OC_DIR/AGENTS.md"
  say "opencode global AGENTS.md -> $DEFAULT_NAME center"
else
  say "SKIPPED opencode AGENTS.md — real file exists; merge it manually"
fi

# ---- opencode: guard plugin (registry-aware, one copy serves all) ---------
mkdir -p "$OC_DIR/plugin"
ln -sfn "$CC_ROOT/bin/adapters/opencode-control-center.js" \
  "$OC_DIR/plugin/opencode-control-center.js"
say "opencode guard plugin linked"

# ---- opencode: lifecycle command shims ------------------------------------
mkdir -p "$OC_DIR/command"
for skill_dir in "$DEFAULT_ROOT"/skills/*/; do
  name="$(basename "$skill_dir")"
  cat >"$OC_DIR/command/$name.md" <<EOF
---
description: Control-center lifecycle: $name
---
Read $DEFAULT_ROOT/skills/$name/SKILL.md and follow it exactly.
EOF
done
say "opencode command shims written"

say "done"

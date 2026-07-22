// opencode plugin adapter for the control-center path guard.
// Symlinked into ~/.config/opencode/plugin/ by bin/link.sh.
// Registry-aware: runs the guard of EVERY registered control center, so
// each center's worktrees are protected no matter where the session
// runs. Delegates to bin/guard-path.sh so the rules live in one place.
// Fails open if a guard script is missing so a broken install never
// bricks a session.
import { execFileSync } from "node:child_process"
import { existsSync, readdirSync, readFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

function centerRoots() {
  const roots = []
  if (process.env.AGENT_CONTROL_CENTER) roots.push(process.env.AGENT_CONTROL_CENTER)
  const registry = join(homedir(), ".config", "agent-control-center", "centers")
  try {
    for (const name of readdirSync(registry)) {
      try {
        roots.push(readFileSync(join(registry, name), "utf8").trim())
      } catch {
        // unreadable entry — skip
      }
    }
  } catch {
    // no registry yet — bootstrap hasn't run
  }
  return [...new Set(roots)]
}

const MODES = {
  read: "read",
  grep: "read",
  glob: "read",
  list: "read",
  edit: "write",
  write: "write",
  patch: "write",
  bash: "bash",
}

export const ControlCenterGuard = async ({ directory }) => ({
  "tool.execute.before": async (input, output) => {
    const mode = MODES[input.tool]
    if (!mode) return

    const args = output.args ?? {}
    const target = mode === "bash" ? args.command : (args.filePath ?? args.path)
    if (!target) return

    for (const root of centerRoots()) {
      const guard = join(root, "bin", "guard-path.sh")
      if (!existsSync(guard)) continue
      try {
        execFileSync(guard, [mode, directory ?? process.cwd(), String(target)], {
          stdio: ["ignore", "ignore", "pipe"],
        })
      } catch (error) {
        if (error?.status === 2) {
          throw new Error(String(error.stderr ?? "blocked by control-center guard"))
        }
        // Any other guard failure fails open.
      }
    }
  },

  // TODO: wire sync.sh pull/push to session lifecycle events once we
  // settle on which opencode event bus signals to trust. Claude Code
  // hooks and the launchd fallback cover sync in the meantime.
})

// opencode plugin adapter for the control-center path guard.
// Symlinked into ~/.config/opencode/plugin/ by bin/link.sh.
// Delegates to bin/guard-path.sh so the rules live in exactly one place.
// Fails open if the guard script is missing so a broken install never
// bricks a session.
import { execFileSync } from "node:child_process"
import { existsSync, readFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

// Resolution order: env override, the pointer file written by bin/link.sh,
// then the conventional location.
function findRoot() {
  if (process.env.AGENT_CONTROL_CENTER) return process.env.AGENT_CONTROL_CENTER
  try {
    return readFileSync(join(homedir(), ".config", "agent-control-center", "root"), "utf8").trim()
  } catch {
    return join(homedir(), "projects", "agent-control-center")
  }
}

const CC_ROOT = findRoot()
const GUARD = join(CC_ROOT, "bin", "guard-path.sh")

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
    if (!mode || !existsSync(GUARD)) return

    const args = output.args ?? {}
    const target = mode === "bash" ? args.command : (args.filePath ?? args.path)
    if (!target) return

    try {
      execFileSync(GUARD, [mode, directory ?? process.cwd(), String(target)], {
        stdio: ["ignore", "ignore", "pipe"],
      })
    } catch (error) {
      if (error?.status === 2) {
        throw new Error(String(error.stderr ?? "blocked by control-center guard"))
      }
      // Any other guard failure fails open.
    }
  },

  // TODO: wire sync.sh pull/push to session lifecycle events once we
  // settle on which opencode event bus signals to trust. Claude Code
  // hooks and the launchd fallback cover sync in the meantime.
})

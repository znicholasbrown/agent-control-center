# agent-control-center

One repository that wraps all local agent work: global agent rules,
skills, guidelines, memory, and a `projects/` directory that holds every
project checkout. Clone this repo on a new machine and you have the
whole setup; project code re-clones on demand from each project's
manifest.

Agent- and model-agnostic by construction: every major agent CLI
(opencode, Codex, Gemini, ...) discovers `AGENTS.md` by walking up the
directory tree, so any session launched under `projects/` inherits the
global rules. Claude Code reads the same file through the one-line
`CLAUDE.md` shim.

## Quickstart (new machine)

```sh
git clone git@github.com:znicholasbrown/agent-control-center.git ~/projects/agent-control-center
cd ~/projects/agent-control-center
./bin/bootstrap.sh   # checks deps, wires hooks + links (idempotent)
```

Then, in any agent session: `/resume-project` to pick up existing work,
or `/start-project` to begin something new.

## Layout

| Path | Committed | Purpose |
|---|---|---|
| `AGENTS.md` | yes | Global rules every agent session inherits |
| `guidelines/` | yes | Writing and coding guidelines |
| `skills/` | yes | Lifecycle skills: start / resume / finish project |
| `memory/` | yes | Global memory (INDEX.md + topic files) |
| `templates/` | yes | PROJECT.md, handoff, notes templates |
| `bin/` | yes | Scripts: worktrees, path guard, sync, bootstrap |
| `projects/INDEX.md` | yes | Registry of all projects |
| `projects/<slug>/` | yes | Manifest, handoffs, notes — the durable record |
| `projects/<slug>/code/` | **no** | Clones + worktrees — disposable, rebuilt from manifest |

## Project lifecycle

- **/start-project** — asks for a name and repos (or a project to
  extend), scaffolds the project directory from templates, blobless-clones
  each repo into `code/<repo>/main`, registers it in `projects/INDEX.md`.
- **/resume-project** — pulls this repo first (latest handoffs from any
  machine), reads the manifest + handoffs + notes, reconciles `code/`
  (re-clones anything missing), continues at Next Steps.
- **/finish-project** — refuses to run if any worktree has uncommitted or
  unpushed work; distills handoffs into the PROJECT.md outcome; promotes
  durable learnings to global memory; deletes `code/`; marks the project
  done.

## Worktree isolation

Agents working in the wrong worktree is the failure mode this repo is
built against. Three layers:

1. **Layout** — each project's checkouts live under its own `code/`
   directory; wrong siblings are not one `cd ..` away.
2. **Instruction** — `AGENTS.md` workspace rules (resolve your root once,
   repo-relative paths in docs, `main` is read-only).
3. **Mechanical** — `bin/guard-path.sh` blocks any file operation that
   resolves into a foreign worktree, wired as a Claude Code PreToolUse
   hook and an opencode `tool.execute.before` plugin.

## Sync

`bin/sync.sh` keeps the remote current: `pull` at session start, `push`
(scoped to `projects/` + `memory/` docs only) at session end, both wired
via hooks by `bootstrap.sh`. A lock directory prevents concurrent
sessions from racing.

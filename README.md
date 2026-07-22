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

## Use as a template

This repository is designed to be a GitHub template. To create your own
control center:

1. Click "Use this template" on GitHub (or fork/copy the files).
2. Clone your new repo anywhere you like — the conventional location is
   `~/projects/agent-control-center`, but nothing depends on it.
3. Run `./bin/bootstrap.sh --name <name>`. The name identifies this
   center in `~/.config/agent-control-center/centers/` and must be
   unique per machine. It also gets written to the committed
   `.control-center` file, so every machine that clones this center
   uses the same name.
4. Make it yours: edit `guidelines/` to your taste, and adjust
   `AGENTS.md` if your machine-sharing or commit rules differ.

## Multiple control centers

You can run several centers on one machine (say, `work` and
`personal`), each created from this template with its own name:

- **Resolution is contextual.** Skills and scripts resolve "which
  center am I in" by walking up from the current directory to the
  nearest `.control-center` marker. The registry's default center (set
  with `bootstrap.sh --default`, shown in
  `~/.config/agent-control-center/default`) is used only for sessions
  outside every center.
- **Guards compose.** Every registered center's path guard runs in
  every session, so worktrees in all centers stay protected no matter
  where you work.
- **Global rule imports go to the default center only** (`~/.claude/CLAUDE.md`
  and opencode's global `AGENTS.md`). A session inside a non-default
  center still gets that center's rules through normal `AGENTS.md`
  directory walk-up.
- **Sync covers all centers.** Session hooks pull and push every
  registered center's docs.

## Quickstart (each additional machine)

```sh
git clone <your-control-center-remote> ~/projects/agent-control-center
cd ~/projects/agent-control-center
./bin/bootstrap.sh   # checks deps, registers the center, wires hooks + links (idempotent)
```

The name travels in the committed `.control-center` file, so no
`--name` is needed on additional machines.

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

# agent-control-center

A shared workspace for your coding agents. It keeps each project's code,
notes, and task handoffs in one place. Any agent, on any machine, can
continue where the last session stopped.

It works with any agent CLI that reads `AGENTS.md`, such as Claude Code,
opencode, Codex, and Gemini CLI.

## Why use it

- **Agents forget between sessions.** Each task keeps a handoff file
  with its current state, decisions, and next steps. The next session
  reads it first and continues from there.
- **Parallel agents get in each other's way.** Each task gets its own
  Git worktree. A guard stops an agent from writing to another
  project's files.
- **Context is stuck on one machine or in one tool.** Handoffs and
  notes are plain Markdown in a Git repository. They sync to every
  machine, and every agent CLI can read them.
- **Rules drift between tools.** One `AGENTS.md` and one set of writing
  and coding guidelines apply to every session.

## When it fits

Use it if you run agent sessions across several repositories or
projects, run more than one session at a time, or move between
machines or agent CLIs.

It adds little if you work in one repository with one agent at a time.
The agent's own memory and the repository's docs are enough for that.

## How it works

**Projects.** Each project is a folder under `projects/`. It holds a
manifest that lists the project's repositories, a `handoffs/` folder,
and a `notes/` folder. The repositories are cloned into the project's
`code/` folder. Code is never committed to the control center; it is
cloned again from the manifest when needed.

**Handoffs.** A handoff is one file per task. It records the goal, the
current state, decisions, dead ends, and next steps. The agent updates
it before each session ends. The next session starts from it.

**Notes.** Notes hold knowledge that lasts longer than one task, such as
designs, plans, and facts about the project's systems. Knowledge that
applies to every project goes to the global `memory/` folder.

**Sync.** A hook pulls the latest handoffs and notes when a session
starts. Another hook pushes them to the control center's Git remote
when the session ends. Only documents sync. Code changes stay in the
project's own repositories, and agents never commit them unless you
ask.

**Isolation.** Each task gets its own worktree. The main checkout of
each repository is read-only. A guard blocks writes outside the current
project, so an agent cannot edit the wrong checkout.

**Trackers (optional).** A project can link to Linear, GitHub Issues,
or Jira. Agents offer to update tickets at the start and end of work.
They never write to a tracker without your approval.

## Daily use

Run these commands in any agent session:

- `/start-project` creates a project, clones its repositories, and
  registers it.
- `/resume-project` pulls the latest documents, checks which branches
  have merged, and summarizes each active task. Add a task name to
  continue that task: `/resume-project <task>`.
- `/finish-project` checks that no work is unpushed, records the
  outcome, saves lasting lessons to global memory, and deletes the
  project's code.

To start work on a repository, create a worktree for the task:

```sh
bin/wt-new <repo> <task-slug>
```

## Set up

You need `git` and `jq`. The `gh` CLI is optional; with it, branch
checks use pull request state.

**First machine.**

1. Create your own repository from this template ("Use this template"
   on GitHub).
2. Clone it. Any location works.
3. Give the center a name that is unique on this machine:

   ```sh
   ./bin/bootstrap.sh --name <name>
   ```

4. Edit `AGENTS.md` and `guidelines/` to match how you work.

**Each additional machine.**

```sh
git clone <your-control-center-remote> ~/projects/agent-control-center
cd ~/projects/agent-control-center
./bin/bootstrap.sh
```

The name is stored in the repository, so you do not need `--name`
again. You can run `bootstrap.sh` again at any time; it is safe to
repeat.

## Several control centers

You can keep separate centers on one machine, for example `work` and
`personal`. Create each one from this template with its own name. A
session uses the center that it runs inside. Sync and the write guard
cover every center on the machine. Add `--default` to `bootstrap.sh` to
choose the center that sessions outside every center use.

## Rules for agents

`AGENTS.md` holds the rules that every session follows: workspace
limits, commit policy, handoff discipline, and how to share the machine
with other sessions. `guidelines/` holds the writing and coding
guidelines, including adjustments for each model.

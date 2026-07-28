# Agent Control Center

This repository is the control center for all agent work on this machine.
It wraps every project checkout. Any agent session launched under
`projects/` inherits these rules.

Layout:

```
agent-control-center/
├── AGENTS.md            ← this file: global rules for every agent
├── guidelines/          ← writing and coding guidelines
├── skills/              ← lifecycle skills (/start-project, /resume-project, /finish-project)
├── memory/              ← global memory (committed, syncs via git)
├── templates/           ← PROJECT.md, handoff, and notes templates
├── bin/                 ← wt-new, wt-ls, wt-prune, guard-path.sh, sync.sh, bootstrap.sh
└── projects/            ← one directory per project
    ├── INDEX.md         ← registry of all projects
    └── <slug>/
        ├── PROJECT.md   ← manifest: repos, remotes, status, extends
        ├── handoffs/    ← one markdown file per task (committed)
        ├── notes/       ← project memory (committed)
        └── code/        ← clones + worktrees (GITIGNORED, disposable)
```

## Workspace discipline

Cross-project mistakes waste time and tokens. Follow these rules:

- Your writable workspace is the current project — every worktree under
  the `projects/<slug>/` you are working in (any repo, any task). You do
  not need to launch inside a specific worktree; being anywhere in your
  project is enough. The guard derives the project from your session's
  working directory.
- Never read or write inside another project's `code/` tree, or another
  control center. A guard hook enforces this; if it blocks you, correct
  your path — do not work around the guard.
- `code/<repo>/main` is a read-only reference. You may read it from any
  project. Never edit it.
- In handoffs, notes, and memory, store repo-relative paths, never
  absolute paths into a specific worktree. Absolute paths go stale when
  worktrees change and cause the next agent to work in the wrong tree.
- Never run `git clean -dfx` at the control-center root. It would delete
  every ignored `code/` directory on the machine.

## Worktree rule

- `code/<repo>/main` is the reference checkout. Read it, pull it, never
  edit it.
- Create a worktree only when you are about to edit repo X and no
  worktree is bound to your current task. Use `bin/wt-new <repo> <task-slug>`.
  It creates `code/<repo>/<task-slug>`, copies untracked env files, and
  creates the task handoff if missing — then binds it to the worktree.
  A handoff without a `worktree:` frontmatter key is unbound.
- Reuse the task's existing worktree for follow-up work on the same
  branch or PR.
- One session may work across all of its project's worktrees; you do not
  need a separate session per worktree.
- Never create a worktree for read-only exploration. Read `main`.

## Memory protocol

| Scope | Location | Content |
|---|---|---|
| Global | `memory/global/` | User preferences, cross-project facts |
| Project | `projects/<slug>/notes/` | Durable project knowledge; spans that project's repos |
| Task | `projects/<slug>/handoffs/<task>.md` | Live session state, next steps |
| Repo | inside each repo (`AGENTS.md`, docs) | Team-owned; travels with the repo |

Rules:

- Read the relevant `INDEX.md` first; open detail files on demand.
- Make line-level edits to memory files. Never rewrite a file wholesale.
- Re-read a memory file immediately before you write to it; another
  session may have changed it.
- On `/finish-project`, distill handoffs and notes into the PROJECT.md
  outcome section, and promote durable cross-project learnings to
  `memory/global/`.

## Handoff discipline

- Read your task's handoff file before starting work.
- Update it before your session ends: current state, decisions made,
  dead ends, and concrete next steps. The next session (possibly on
  another machine, possibly another agent CLI) starts from that file.
- Reference plans, ADRs, and commits by path or hash. Do not restate
  their content.

## Sync and commit policy

- Agents may commit and push ONLY control-center documentation:
  `projects/**` (docs; `code/` is gitignored and cannot be committed) and
  `memory/**`. Use `bin/sync.sh push` — it is scoped to those paths.
- Never commit or push inside any repo under `code/` unless the user
  explicitly asks for it in the current session.
- Hooks run `bin/sync.sh pull` at session start and `bin/sync.sh push` at
  session end so the remote always has current handoffs.

## Shared machine

Many agents and the user share this machine:

- Do not stop a process you did not start. Never `kill` or `pkill` a dev
  server unless you started that exact process in this session and
  recorded its PID.
- Before you start a dev server, check whether one already answers on
  the expected port. If it does, use it.
- Do not restart a running dev server to fix a problem. Ask the user
  first.
- If you start a long-running process, run it in the background and
  record its PID. Stop only that PID when you finish.

## Scratch files

Never write scratch or temporary files to `/tmp`, `$TMPDIR`, or the home
directory. Create a `.tmp/` directory inside your current workspace and
use that. It is disposable.

## Guidelines

- Writing (docs, copy, handoffs): follow `guidelines/writing.md`.
- Code: follow `guidelines/coding.md`, and defer to the conventions of
  the repo you are working in.

---
name: start-project
description: Start a new project in the agent-control-center - scaffolds the project directory, clones its repos, and registers it. Use when the user wants to begin a new project or initiative.
---

# /start-project

Control center root: `~/projects/agent-control-center` (called `$CC` below).

## Steps

1. **Gather inputs.** Ask the user, one question at a time, unless they
   already provided the answers:
   - Project name (derive a kebab-case slug from it; confirm the slug).
   - Which repositories to include. Accept remote URLs, or names of
     repos already present in other projects (reuse their remotes).
   - Optionally: an existing project to extend. If given, copy its
     `repos` list as the starting point and record `extends: <slug>`.
2. **Check the registry.** Read `$CC/projects/INDEX.md`. If the slug is
   taken, ask for another.
3. **Scaffold.** Create `$CC/projects/<slug>/` with `handoffs/`,
   `notes/`, and `code/`. Instantiate:
   - `PROJECT.md` from `$CC/templates/PROJECT.md` — fill name, slug,
     today's date, `extends`, and one `repos` entry per repository
     (name, remote, default branch).
   - `notes/INDEX.md` from `$CC/templates/notes-index.md`.
4. **Clone.** For each repo:
   `git clone --filter=blob:none <remote> $CC/projects/<slug>/code/<name>/main`
   Blobless clones keep large repos cheap; file contents download on
   demand.
5. **Register.** Append a row to `$CC/projects/INDEX.md`:
   `| <slug> | active | <repo names> | <date> |`
6. **Seed the first handoff.** Ask the user for the project goal (one or
   two sentences). Write it into PROJECT.md's Goal section, and create
   `handoffs/project-setup.md` from the handoff template with the goal
   and the user's first concrete next steps.
7. **Sync.** Run `$CC/bin/sync.sh push`. This commits and pushes ONLY
   control-center docs (`projects/`, `memory/`) — this narrow scope is
   sanctioned; never commit anything under `code/`.
8. **Report.** Tell the user the project path, the repos cloned, and
   suggest `cd $CC/projects/<slug>` for their next session.

## Rules

- Do not create any worktrees yet. Worktrees are created per task with
  `$CC/bin/wt-new` when editing actually starts.
- If a clone fails, report it, leave the manifest entry in place, and
  continue with the remaining repos — `/resume-project` reconciles later.
- Editing the repo list later = edit `PROJECT.md`'s `repos` frontmatter,
  then `/resume-project` reconciles the clones.

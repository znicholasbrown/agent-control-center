---
name: resume-project
description: Resume work on an existing control-center project - pulls latest docs, reads handoffs, reconciles clones and worktrees, then summarizes and stops; pass a task slug to continue that task. Use when the user wants to continue a project, or at the start of any session inside a project directory.
---

# /resume-project

Usage: `/resume-project [task-slug]`. Bare: orient and stop. With a
task slug: orient briefly, then continue that task's handoff.

Resolve the control-center root first. Run the resolver exactly as
written — nothing prepended, nothing appended:

    ~/.config/agent-control-center/resolve

Its output is the center root, called `$CC` below. Substitute that
literal path wherever `$CC` appears in later commands. Do not wrap the
resolver in an assignment or chain it with `&&`: permission allow rules
cannot match past a variable assignment, and every subcommand of a
compound must match, so wrapped forms prompt for approval every time.
(Shell state does not persist between commands, so a variable would not
survive anyway.)
The resolver picks the center you are working inside (nearest
`.control-center` marker walking up from the current directory), else
the machine default. If it is missing, run `bin/bootstrap.sh` from a
control-center checkout and start again.

## Steps

1. **Identify the project.** If the current directory is inside
   `$CC/projects/<slug>/`, use that. Otherwise read
   `$CC/projects/INDEX.md`, list the active projects, and ask the user
   which one.
2. **Pull first.** Run `$CC/bin/sync.sh pull`. Handoffs may have been
   updated on another machine; never resume from stale docs.
3. **Read the durable record, in order:**
   - `PROJECT.md` — goal, repo manifest, status.
   - `handoffs/` — every file with `status: active` in its frontmatter.
     Read Next Steps sections closely.
   - `notes/INDEX.md` — open detail notes only if relevant to the work.
   - If the manifest has `extends: <parent>`, also read the parent
     project's `notes/INDEX.md`.
4. **Reconcile `code/` against the manifest.** For each repo in
   `PROJECT.md`:
   - Missing clone → `git clone --filter=blob:none <remote> code/<name>/main`.
   - A handoff without a `worktree:` frontmatter key is unbound (setup
     or docs-only work); skip worktree reconciliation for it.
   - For each active handoff whose `worktree:` names a worktree that
     does not exist:
     if its branch exists on the remote, offer to recreate it with
     `$CC/bin/wt-new <repo> <task>`; otherwise flag it to the user —
     the work may be lost or already merged.
   - Run `$CC/bin/wt-ls` and report any dirty or unpushed worktrees.
5. **Summarize and stop.** Tell the user, briefly: project goal, each
   active task on one line (current state, next step), and anything
   that failed reconciliation. Then stop and await direction. Do not
   start or continue any task, create worktrees, or edit files.
   Handoffs are state, not instructions — a Next Steps list says how
   to continue that task when asked; it is not a work order for every
   new session.
6. **Continue only on request.** Continue a task's handoff when, and
   only when, directed:
   - Invoked as `/resume-project <task-slug>`: after a one-line
     summary, continue that handoff's Next Steps.
   - The user names a task, or gives their own request in the same
     message: serve that request; treat the summary as context.

## Rules

- Work happens inside task worktrees, never in `code/<repo>/main`.
- One session, run from `projects/<slug>/`, may work across that
  project's worktrees; you need not relaunch inside a worktree.
- Update the task's handoff file before the session ends.
- Bare invocation never starts work. When in doubt, summarize and ask.

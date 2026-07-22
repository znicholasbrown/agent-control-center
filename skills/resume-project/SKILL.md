---
name: resume-project
description: Resume work on an existing control-center project - pulls latest docs, reads handoffs, reconciles clones and worktrees. Use when the user wants to continue a project, or at the start of any session inside a project directory.
---

# /resume-project

Resolve the control-center root first (called `$CC` below):
`CC=$(~/.config/agent-control-center/resolve)`
This picks the center you are working inside (nearest `.control-center`
marker walking up from the current directory), else the machine default.
If the resolver is missing, run `bin/bootstrap.sh` from a control-center
checkout and start again.

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
5. **Summarize and continue.** Tell the user, briefly: project goal,
   state of each active task, anything that failed reconciliation. Then
   continue with the most recent handoff's Next Steps (or the task the
   user names).

## Rules

- Work happens inside task worktrees, never in `code/<repo>/main`.
- Update the task's handoff file before the session ends.

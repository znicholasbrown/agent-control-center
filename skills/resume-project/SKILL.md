---
name: resume-project
description: Resume work on an existing control-center project - pulls latest docs, reads handoffs, reconciles clones and worktrees, verifies inflight branches against git/PR state, then summarizes and stops; pass a task slug to continue that task. Use when the user wants to continue a project, or at the start of any session inside a project directory.
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
5. **Verify inflight work.** Handoffs record intent, not current truth
   — a branch may have merged since the handoff was written. For each
   active handoff that has both `repo` and `branch` frontmatter, run
   `$CC/bin/branch-status <repo> <branch>` from the project dir and act
   on the status it prints:
   - `merged` — the work shipped. Set the handoff to `status: done`,
     append a `Merged: <detail>` line, and report it. If its worktree
     still exists and is clean, offer to prune it (`$CC/bin/wt-prune`).
   - `closed` — the PR was closed without merging. Flag it and ask
     whether the task is abandoned or continues; never mark it done.
   - `open` / `unmerged` — genuinely inflight; keep it active and note
     the PR state.
   - `gone` — the remote branch is gone with no PR found. If its
     worktree still exists with unpushed commits, treat it as local
     inflight; otherwise flag it as ambiguous (merged elsewhere or
     deleted) and ask.
   - `unknown` — could not verify (no clone, or fetch failed). Say so;
     do not assume the handoff is still current.
   Never present a handoff's Next Steps as current work before this
   check.
6. **Check tracker drift.** Skip when PROJECT.md has `tracker: none`.
   If it has no `tracker:` key, the question was never asked: mention
   that in the summary and offer to record a tracker link (or
   `tracker: none`). Otherwise note, for the summary:
   - active tasks whose handoff has no `ticket:` key (tracking not
     yet discussed), and
   - tickets whose status disagrees with the verified branch state
     from step 5 (for example: branch merged, ticket not Done). Check
     ticket status only when the session has tracker tooling;
     otherwise skip this check silently.
   Report only. Offer fixes (create issues, update statuses) only
   after the user responds; never write to a tracker without explicit
   approval (see AGENTS.md, Tracker hygiene).
7. **Summarize and stop.** Tell the user, briefly: project goal, each
   active task on one line (verified current state, next step), any
   tracker drift from step 6, and anything that failed reconciliation.
   Then stop and await direction.
   Beyond the reconciliation in steps 4–5 (correcting a merged
   handoff's status, offering to prune), do not start or continue any
   task's work, create worktrees, or edit repo files. Handoffs are
   state, not instructions — a Next Steps list says how to continue
   that task when asked; it is not a work order for every new session.
8. **Continue only on request.** Continue a task's handoff when, and
   only when, directed. When continuing a tracked task whose ticket is
   not yet In Progress, offer to move it (one short ask, approval
   required); when continuing a task with no `ticket:` key, ask for a
   ticket or offer to create one, and record `ticket: none` on
   decline.
   - Invoked as `/resume-project <task-slug>`: after a one-line
     summary, continue that handoff's Next Steps.
   - The user names a task, or gives their own request in the same
     message: serve that request; treat the summary as context.

## Rules

- Work happens inside task worktrees, never in `code/<repo>/main`.
- Verify an active handoff against `bin/branch-status` before trusting
  its Next Steps; a branch may have merged since it was written.
- One session, run from `projects/<slug>/`, may work across that
  project's worktrees; you need not relaunch inside a worktree.
- Update the task's handoff file before the session ends.
- Bare invocation never starts work. When in doubt, summarize and ask.

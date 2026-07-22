---
name: finish-project
description: Finish a control-center project - verifies nothing is unpushed, distills docs into an outcome, promotes learnings, deletes the code directory, marks the project done. Use when the user says a project is complete or wants to wrap it up.
---

# /finish-project

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

1. **Identify the project** (same as /resume-project step 1) and run
   `$CC/bin/sync.sh pull`.
2. **SAFETY GATE — never skip.** For every worktree AND every
   `code/<repo>/main` clone in the project, check:
   - `git status --porcelain` is empty (no uncommitted work), and
   - `git rev-list --count @{upstream}..HEAD` is 0 where an upstream
     exists; a branch with no upstream and local commits counts as
     unpushed.
   If anything fails, STOP. List the offenders and ask the user to
   resolve them (or explicitly confirm the work is disposable) before
   continuing. Deleting `code/` is only safe when every commit is on a
   remote.
3. **Distill the outcome.** Write PROJECT.md's Outcome section from the
   handoffs and notes: what shipped (PR links), key decisions, and an
   explicit list of loose ends. Reference PRs and commits by link or
   hash; do not restate diffs.
4. **Promote durable learnings.** Anything useful beyond this project
   goes to `$CC/memory/global/` (update `memory/INDEX.md`), or becomes a
   new skill in `$CC/skills/` if it is a reusable procedure. Ask the
   user before creating a new skill.
5. **Close out the docs.** Set `status: done` in PROJECT.md frontmatter
   and in every handoff's frontmatter; update the project's row in
   `$CC/projects/INDEX.md`.
6. **Delete `code/`.** For each repo: `git -C code/<repo>/main worktree
   remove <path>` for every worktree, then delete the repo directory.
   Finally remove the project's `code/` directory entirely. The
   committed docs and the remotes are the durable record.
7. **Sync.** Run `$CC/bin/sync.sh push` (control-center docs only).
8. **Report.** Outcome summary, loose ends, and disk reclaimed.

## Rules

- The safety gate is absolute: never delete a worktree with uncommitted
  or unpushed work without the user's explicit, per-worktree consent.
- Pausing instead of finishing: set `status: paused` in PROJECT.md and
  the registry, keep or prune `code/` per the user's preference, skip
  steps 3–6.

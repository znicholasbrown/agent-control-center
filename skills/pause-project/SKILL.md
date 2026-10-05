---
name: pause-project
description: Save this session's in-flight state to the project docs so context can be cleared safely. Use when the user is putting work down, stopping for now, switching away, or about to /clear or compact inside a control-center project.
---

# /pause-project

This skill saves the session, not the project. It does not change
PROJECT.md status. To pause a whole project, follow the "Pausing
instead of finishing" rule in /finish-project.

Resolve the control-center root first. Run the resolver exactly as
written, with nothing prepended or appended:

    ~/.config/agent-control-center/resolve

Its output is the center root, called `$CC` below. Substitute that
literal path wherever `$CC` appears in later commands. Do not wrap the
resolver in an assignment or chain it with `&&`: permission allow rules
cannot match past a variable assignment, and every subcommand of a
compound must match, so wrapped forms prompt for approval every time.

## Steps

The order matters. Every local save happens before the one question
to the user, so nothing is lost if the user leaves before answering.

1. **Identify the project** (same as /resume-project step 1). List
   every task this session touched. Use the conversation, not only
   the handoffs marked active.
2. **Update each touched handoff.** Re-read it first, then make
   line-level edits, even to a small file: another session may have
   changed it, and a whole-file write erases those changes. Edit the
   sections in `$CC/templates/handoff.md`:
   current state (include uncommitted work and where it is),
   decisions with their reasons, dead ends, and concrete next steps.
   Set `updated:` to today. Set `status: done` only for work that is
   verified finished, and say how it was verified. If real work has
   no handoff yet, create one from the template.
3. **Save durable facts.** Facts that outlive the task go to
   `notes/` and `notes/INDEX.md`. Facts that apply beyond this
   project go to `$CC/memory/global/`.
4. **Check repo state.** Run `$CC/bin/wt-ls`. Record dirty or
   unpushed worktrees in their handoffs. Do not commit, stash, or
   push inside `code/`; that is the user's decision.
5. **Draft the tracker batch.** Skip this step and step 7 when
   PROJECT.md has `tracker: none` or the session has no tracker
   tooling. If PROJECT.md has no `tracker:` key, mention that once in
   the report. Otherwise list one write per touched ticket: finished
   work moves to Done with the PR link; in-flight work gets a
   progress comment only when its handoff gained a decision or a
   status change. Add the list to each affected handoff's Next steps
   as `Pending tracker update (not approved): <write>`.
6. **Push the docs.** Run `$CC/bin/sync.sh push` as its own command,
   never chained with a tracker call. Do not rely on the session-end
   hook; it can be killed before it finishes.
7. **Ask once.** Show the exact batch from step 5 and ask one
   approve-or-skip question. Apply only what the user approves, then
   remove those pending lines and push again.
8. **Report.** One line first: safe to clear, or what is not yet
   safe (failed push, unpushed docs). Then list uncommitted or
   unpushed code; it survives a clear but not a move to another
   machine. Do not start new work.

## Tracker approval

AGENTS.md requires approval of a concrete, stated batch. These do
not count as approval, because the user has not yet seen the writes:

| Words or situation | Why it is not approval |
|---|---|
| "update the tickets" | Names the action, not the writes. |
| "just do it, don't ask me" | The batch was never shown. |
| Running /pause-project | The skill asks for the batch; it does not grant it. |
| The write is obvious (PR merged) | Obvious writes still need one yes. |

If the user does not answer, the pending lines from step 5 are the
record. The next session finds them in the handoff.

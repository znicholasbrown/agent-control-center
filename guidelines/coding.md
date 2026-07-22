# Coding guidelines

These are cross-project defaults. The conventions of the repo you are
working in always win.

- Match the surrounding code: naming, idiom, comment density, and file
  organization.
- Make the smallest change that solves the problem. No drive-by
  refactors; propose them separately instead.
- Write a code comment only for a constraint the code cannot show.
  Never narrate what the next line does or why a change is correct.
- Run the repo's own verification (tests, lint, typecheck) before
  claiming work is done, and report the actual output.
- Never commit, push, or open PRs unless the user explicitly asks in
  the current session. The one exception is control-center docs via
  `bin/sync.sh push`.
- Prefer boring technology. Introduce a new dependency only when the
  task cannot reasonably be done without it, and say so in the handoff.

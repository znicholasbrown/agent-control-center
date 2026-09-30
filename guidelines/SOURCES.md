# Sources for the writing and model guidelines

Read on 2026-09-29. Each rule in `writing.md` and `models.md` comes from
the Claude prompt-engineering docs, from a rule the user set, or from
both. When the docs change, re-read the pages below and update the
matching file. Base URL:
`https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/`

| Page | Short name |
|---|---|
| `claude-prompting-best-practices` | BP |
| `prompting-claude-fable-5-1` | F51 |
| `prompting-claude-fable-5` | F5 |
| `prompting-claude-opus-5-5` | O55 |
| `prompting-claude-opus-5` | O5 |
| `prompting-claude-sonnet-5-5` | S55 |
| `prompting-claude-sonnet-5` | S5 |

## writing.md

| Section | Source |
|---|---|
| Plain language | User rule (ASD-STE100) |
| Say what you mean | F51, "Writing density" (verbatim); design rules are a user rule, 2026-09-29 |
| Lead with the outcome | F5, "Strong instruction following"; BP, "Eliminating preambles" |
| Readable before short | F5, "Strong instruction following" |
| Final summaries | F5, "Readability when communicating with the user" |
| Honest reports | F5, "Ground progress claims during long runs"; O5, "Self-correction" |
| Formatting | F51, "Formatting in chat"; bold-title bullets and no em-dashes are user rules |
| Rules you write for agents | BP, "Add context to improve performance", "Tool usage", "Control the format of responses" |

## models.md

| Section | Source |
|---|---|
| `claude-opus-5` | O5: "User-facing progress updates", "Written deliverable length", scope, subagents |
| `claude-opus-5-5` | O55: "User-facing progress updates", reopening settled answers |
| `claude-fable-5` | F5: state the boundaries, pause only when needed, scope, subagents, context-budget concern |
| `claude-fable-5-1` | F51: progress updates, scope and tests, search triggering, batch tool calls |
| `claude-sonnet-5` | S5: "Response length and verbosity", "More literal instruction following" |
| `claude-sonnet-5-5` | S55: "Steer initiative and scope", "Verification on coding tasks", search |

## Left out on purpose

- BP's anti-markdown block. It conflicts with the user's bold-title
  bullet rule, and F51 says it suppresses needed structure on Fable 5.1.
- Rules that Claude Code already sends in its own system prompt, such
  as "When you have enough information to act, act" and the nudge
  after a long silence.
- Rules for unattended runs (F51 "Finish the whole task", O55 standing
  instruction). This harness has a person in the loop.
- Frontend aesthetics. These are design rules, not writing rules.

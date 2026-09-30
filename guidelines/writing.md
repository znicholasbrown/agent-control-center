# Writing guidelines

These rules apply to everything an agent writes for a person: replies,
final summaries, docs, handoffs, notes, PR text, UI copy, and design
labels. The source of each rule is in `guidelines/SOURCES.md`.
Model-specific adjustments are in `guidelines/models.md`.

## Plain language

Write with `ASD-STE100 Simplified Technical English` conventions. A
reader who skims or reads in a second language must still get the
meaning.

- Short sentences; one instruction or idea per sentence.
- Active voice, present tense where possible.
- Simple, consistent vocabulary. Use one term for one concept. Avoid
  jargon unless it is a defined technical term.
- Prefer clarity and precision over style or cleverness.

## Say what you mean

Mannered prose substitutes metaphor and flourish for direct statement.
Instead of "a parameter worth varying," the mannered writer produces "a
dial worth turning." Instead of "this point still matters," they write
"this point earns its keep." The phrases exist to display the writer,
not to convey the idea, and readers can tell. That is why mannered
prose irritates: it makes the reader work harder so the writer can
perform. It is also imprecise. Metaphors drag in connotations the
writer did not choose and cannot control. The fix is to say what you
mean. When a literal phrase is available, use it.

In a design (board titles, labels, captions, annotations, UI text):

- A label names the fact: "credits left", not "the supply cap".
- A caption states what the drawing shows and what it implies. It does
  not narrate, and it does not borrow an image from another domain.
- A reference to prior art (a game, a map, a cockpit) may name the
  source once. After that, use our own terms.
- Before you publish a board, read every string on it and replace each
  metaphor with the literal phrase it stands for.

## Lead with the outcome

The first sentence answers "what happened" or "what did you find". Put
supporting detail and reasoning after it. Start the answer directly,
without a preamble such as "Here is..." or "Based on...".

## Readable before short

Being readable and being concise are different things, and readability
matters more. Keep output short by choosing what to include: drop
details that do not change what the reader does next. Do not compress
the writing into fragments, abbreviations, arrow chains such as
`A → B → fails`, or hyphen-stacked compounds.

## Final summaries

Terse notes between tool calls are fine. The final message is for a
reader who did not watch the work, so write it as a re-grounding:

- Open with one sentence on the outcome, then the one or two things you
  need from the reader.
- Drop the working vocabulary. Spell out terms, and do not use labels
  you made up during the work.
- Give each file, commit, flag, or identifier its own plain-language
  clause.
- If you must choose between short and clear, choose clear.

## Honest reports

- Report only work that a tool result from this session supports. If
  something is not verified, say so.
- If a check fails, say so and show the output. If you skipped a step,
  say that. When something is done and verified, state it plainly
  without hedging.
- Correct an earlier statement only when the error changes the user's
  code, conclusions, or decisions. State the correction briefly, then
  continue. Fix slips that change nothing without comment.

## Formatting

- Use a list when the content has several separate items, or when the
  reader asked for one. For a group of related points, use a bold title
  and short bullets, not a paragraph of short sentences.
- In a conversational or personal exchange, write plain prose.
- If the reader asks for minimal formatting, use no headers, lists, or
  bold.
- Do not use em-dashes in copy. Use a comma, a semicolon, or a separate
  sentence.

## Rules you write for agents

When you write a prompt, skill, or memory entry for another agent:

- Give the reason with the rule. A model follows an explained rule more
  reliably and applies it to cases the rule does not name.
- Use calm wording. Current models over-apply "CRITICAL" and "You
  MUST"; "Use this tool when..." works better.
- Say what to do, not only what to avoid.

## Documents in this control center

- Lead with the outcome or the current state. Detail comes after.
- Reference files, commits, and PRs by path, hash, or URL. Do not
  restate their content.
- Convert relative dates ("yesterday", "last week") to absolute dates.
- Store repo-relative paths, never absolute paths into a worktree.

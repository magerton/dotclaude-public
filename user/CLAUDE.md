# Writing style (global)

No mannered prose. Follow McCloskey's Economical Writing. Write plain, declarative sentences: workmanlike, every word counting, like a tight empirical economics paper. Applies to everything the agent writes: documents, chat, comments, commits.

Do: Lead with the claim: no windup or closing flourish. Use concrete nouns, active verbs. Cut adjectives, and especially adverbs, as these usually mean you're telling, not showing. Say "I don't know" instead of writing around a gap.

Don't: assert without evidence; use rhetorical flourishes; say "it's not X, it's Y"; use metaphor in place of substance.

Vocabulary: make the terminology work for the reader. Use the standard term in the reader's field; if none exists, describe the thing in plain words. Coin a term only when the plain version is clunky; define each coined term and each new symbol in one plain sentence at first use in each document or message, and avoid collisions with standard meanings or with another use in the same document. Don't use ordinary words in a private sense ("exposed to estimation error") or label objects with names the reader was never taught. Table headers and lemma names must stand alone.

Authorship: label everything an agent writes, so a reader always knows whether a human or an AI wrote it. Documents (memos, plans, reviews, READMEs, slides) carry an author line naming the agent, such as `Author: Claude (AI), for @handle`; code an agent writes says so in its header; drafts written for someone else to send (emails, messages, PR descriptions) say in their text that the agent drafted them. A person's own words appear only in quotes, attributed to them.

# Long-running projects (repos with a `STATUS.md`)

A repo with a `STATUS.md` is a long project; these rules apply there and nowhere else. The project `CLAUDE.md` names where the record files and the results folder live.

- **`STATUS.md`**: one screen, overwritten. A dates line (deadline, next meeting, absences); current goal and tasks; open decisions for the user as numbered yes/no questions; the active plan; how to resume. When the user answers a numbered question, move the answer to LOG and delete it from STATUS. Rewrite STATUS in the same commit as any change to the state of the work.
- **`STRATEGY.md`**: the goal and how the project means to reach it, held as a working hypothesis. Challenge it and draft alternative framings whenever the evidence suggests a better one; adopt a change only after the user says yes.
- **`LOG.md`**: append-only; each entry is `YYYY-MM-DD-HHh-MMm TAG text`, stamped from `date +%Y-%m-%d-%Hh-%Mm`. An entry an agent writes carries `(AI)` before the tag: `YYYY-MM-DD-HHh-MMm (AI) TAG text`. Tags:
  - `DECISION`: who decided and where, in the user's own words where the wording matters; a reversal names the entry it replaces.
  - `FINDING`: one line and a link to the artifact.
  - `DEAD-END`: what was tried and why it failed.
  - `IDEA`: a candidate not yet adopted.
  - `LESSON`: about how the work is going, written whenever the user or the agent notices one.

  Commit hashes are optional. Open questions belong in STATUS. Before starting new work, grep LOG and cite what it finds, or say nothing was found.
- **Commit or LOG.** A commit message says what changed and why; LOG holds what was learned or decided. Longer reasoning goes in a memo or plan that LOG links to.
- **Preserve work.** Substantive results, and anything needed to reproduce or resume an investigation, go in committed files in the results folder before the session moves on. A conversation or scratchpad is never the only record; throwaway output goes in a gitignored `scratch/`.
- **Plans.** Copy an approved plan to `plans/YYYY-MM-DD-HHh-MMm-<slug>.md` with a status (DRAFT, APPROVED, RUNNING, DONE, ABANDONED, SUPERSEDED BY <file>) and commit it alone; the message names the path and says, in searchable words, what the plan does, why, and what it rejected.
- **Headers.** Memos, reviews and plans start with `Date:`, `Status:` and `Summary:` lines.
- **Cleanup at check-ins.** Completed research artifacts (memos, literature reviews, proofs, analyses) stay. Delete obsolete intermediates: review reports whose findings have been applied, superseded drafts, finished plans. Move any caveat into a living file first, and list the deleted files in the commit message. `git log --diff-filter=D --name-only` lists them later; `git log -S'<text>'` searches their text.
- **Agent memory** (in Claude Code, auto-memory) holds only facts about the user that apply across projects. Project facts go in the files above.

# Writing style (global)

No mannered prose. Follow McCloskey's Economical Writing. Write plain, declarative sentences: workmanlike, every word counting, like a tight empirical economics paper. Applies to everything the agent writes: documents, chat, comments, commits.

Do: Lead with the claim: no windup or closing flourish. Use concrete nouns, active verbs. Cut adjectives, and especially adverbs, as these usually mean you're telling, not showing. Say "I don't know" instead of writing around a gap.

Don't: assert without evidence; use rhetorical flourishes; say "it's not X, it's Y"; use metaphor in place of substance.

Vocabulary: make the terminology work for the reader. Use the standard term in the reader's field; if none exists, describe the thing in plain words. Coin a term only when the plain version is clunky; define each coined term, new symbol, and abbreviation or label the reader may not know in one plain sentence at first use in each document or message, and avoid collisions with standard meanings or with another use in the same document. Don't use ordinary words in a private sense ("exposed to estimation error") or label objects with names the reader was never taught. Table headers and lemma names must stand alone.

Authorship: label everything an agent writes, so a reader always knows whether a human or an AI wrote it. Documents (memos, plans, reviews, READMEs, slides) carry an author line naming the agent, such as `Author: Claude (AI), for @handle`; code an agent writes says so in its header; drafts written for someone else to send (emails, messages, PR descriptions) say in their text that the agent drafted them. A person's own words appear only in quotes, attributed to them.

Posts: an agent may post short comments to an existing GitHub issue or PR; it opens no issue and @-mentions, assigns or requests review from no one unless the user asks. A post addressed to a coauthor goes to the user first.

# Long-running projects (repos with a `STATUS.md`)

A repo with a `STATUS.md` is a long project; these rules apply there and nowhere else. The project instructions (`CLAUDE.md`, or the `AGENTS.md` it imports) name where the record files and the results folder live.

- **`STATUS.md`**: one screen, overwritten. A dates line (deadline, next meeting, absences); a "Last period" block (goals set at the last check-in, what was done against them, what is next); current goal and tasks; open decisions for the user as numbered yes/no questions; the active plan; how to resume, including where the kickoff prompts for the next sessions are. When the user answers a numbered question, move the answer to LOG and delete it from STATUS. Rewrite STATUS in the same commit as any change to the state of the work.
- **`STRATEGY.md`**: the goal and how the project means to reach it, held as a working hypothesis. Challenge it and draft alternative framings whenever the evidence suggests a better one; adopt a change only after the user says yes.
- **`LOG.md`**: append-only; each entry is `YYYY-MM-DD-HHh-MMm TAG text`, appended with `log-entry` (`~/.claude/bin/log-entry`, or `.dotclaude/bin/log-entry`), which stamps from `date`; where neither exists, stamp from `date +%Y-%m-%d-%Hh-%Mm`. Never type a stamp. An entry an agent writes carries `(AI)` before the tag: `YYYY-MM-DD-HHh-MMm (AI) TAG text`. Tags:
  - `DECISION`: who decided and where, in the user's own words where the wording matters; a reversal names the entry it replaces.
  - `FINDING`: one line and a link to the artifact.
  - `DEAD-END`: what was tried and why it failed.
  - `IDEA`: a candidate not yet adopted.
  - `LESSON`: about how the work is going, written whenever the user or the agent notices one.

  Commit hashes are optional. Open questions belong in STATUS. Before starting new work, grep LOG and cite what it finds, or say nothing was found.
- **Commit or LOG.** A commit message says what changed and why, written from `git diff --cached`; LOG holds what was learned or decided. Longer reasoning goes in a memo or plan that LOG links to.
- **Preserve work.** Substantive results, and anything needed to reproduce or resume an investigation, go in committed files in the results folder before the session moves on. A conversation or scratchpad is never the only record; throwaway output goes in a gitignored `scratch/`.
- **Plans.** Copy an approved plan to `plans/YYYY-MM-DD-HHh-MMm-<slug>.md` with a status (DRAFT, APPROVED, RUNNING, DONE, ABANDONED, SUPERSEDED BY <file>) and commit it alone; the message names the path and says, in searchable words, what the plan does, why, and what it rejected.
- **Headers.** Memos, reviews and plans start with `Date:`, `Status:` and `Summary:` lines.
- **Cleanup at check-ins.** Completed research artifacts (memos, literature reviews, proofs, analyses) stay. Delete obsolete intermediates: review reports whose findings have been applied, superseded drafts, finished plans. Move any caveat into a living file first, and list the deleted files in the commit message. `git log --diff-filter=D --name-only` lists them later; `git log -S'<text>'` searches their text.
- **Parallel sessions.** When another session is open on the same repo, work in your own git worktree and branch unless the user says the sessions share one; merge back without rebasing. Check the branch and the staged diff before each commit, push or publish. The project instructions say how compute jobs avoid oversubscribing the machine's threads; if they say nothing, propose a rule to the user before running multi-threaded jobs in parallel.
- **Agent memory** (in Claude Code, auto-memory) holds only facts about the user that apply across projects. Project facts go in the files above.

# Shared repos (several people, possibly several agents)

A long project whose `AGENTS.md` lists a team is shared. There, in addition to the rules above:

- **The user** is the person running the session. Find their GitHub handle with `gh api user --jq .login`; failing that, `git config user.name`; failing that, ask.
- **LOG** entries carry the handle after the stamp: `YYYY-MM-DD-HHh-MMm @handle TAG text`, or `YYYY-MM-DD-HHh-MMm @handle (AI) TAG text` when an agent writes it (`log-entry --handle @handle`). A DECISION names who decided, who may be someone other than the session's user.
- **STATUS**: the second line is `Updated: YYYY-MM-DD @handle`. Each open question names whom it is for: `1. **(@handle)** ...`. Remove only answered questions; never drop another person's question or task.
- **STRATEGY** binds no one until a coauthor approves it, in a meeting or in writing; its `Status:` line names who approved the current version and the LOG entry that records it. An agent never adopts a change on its own, and a draft STRATEGY is no reason to interrupt other work.
- **Author lines**: `Author: @handle` for a person, `Author: <agent> (AI), for @handle` for an agent.
- **Git.** Never rebase, squash or force-push: LOG entries cite commit hashes. `.gitattributes` has `LOG.md merge=union`, so local merges keep both sides' entries; check the merged LOG is in time order. Resolve STATUS and STRATEGY conflicts by hand, keeping both authors' content.
- **Agents differ.** Where a step needs a feature the session's agent lacks (Claude Code skills, hooks, subagents), do the nearest equivalent by hand or skip the step and say so. A skill's instructions are in `.dotclaude/skills/<name>/SKILL.md`.
- **Per-user facts** (operating system, local paths, preferences) go in the gitignored `CLAUDE.local.md`. Claude Code loads it; other agents read it at session start if it exists.

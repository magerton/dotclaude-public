---
name: checkin
description: Check-in for a long project (a repo with STATUS.md). Two goals - bring the records and repo in line with the workflow (missing findings logged, intermediates cleaned up, STATUS and STRATEGY current), and reflect on whether Claude made good research decisions (LESSON entries).
disable-model-invocation: true
argument-hint: "[focus or note]"
---

# Check-in

A check-in has two goals:
1. **Housekeeping.** The records and the repo match the long-project rules (dotclaude's `user/CLAUDE.md`, "Long-running projects"): LOG holds the substantive findings and decisions, STATUS is true and one screen, STRATEGY reflects the results, obsolete intermediates are gone.
2. **Metacognition.** Given what we were trying to accomplish, did Claude make good research decisions, and what should it do differently? Efficiency is part of this, not the whole. Record the answers as `LESSON` entries.

The user's note for this check-in, if any: $ARGUMENTS

Stage files by path; the user may be editing in the IDE or in another session.

1. **Orient and fix drift.** Find the last tag (`git describe --tags --match 'checkin-*' --abbrev=0`; if none, the last two weeks). Read STATUS, STRATEGY, and LOG and `git log` since then. Record substantive findings and decisions missing from LOG (routine commits need no entry), and fix STATUS claims the repo contradicts.
2. **Project steps.** If the project `CLAUDE.md` (or a nested one, e.g. `tex/theory/CLAUDE.md`) has a "Check-ins" section, run its steps. Where one matches a step below (tagging, cleanup, STRATEGY proposals, decisions for the user), do it once, at the step below. Reviews run in fresh-context subagents and return short summaries.
3. **Reflect.** The question: given what we were trying to accomplish, did Claude make good research decisions, and what should it do differently? Weigh the user's corrections, comments and decisions, and the artifacts themselves, above Claude's own reading of its work.
   - Judgment: did Claude pick questions that mattered, try the simpler argument or decisive test first, drop a line once its relevance became doubtful, catch its own errors before presenting, and contribute an interpretation, hypothesis or change of direction?
   - Communication: where did an unclear explanation, a private term, excess detail or a missing "how this fits" cost the user a question or a correction?
   - Writing rules: where the user rewrote, rejected or complained about Claude's prose (their edits to text Claude drafted, their corrections in conversation), ask what change to the writing section of dotclaude's `user/CLAUDE.md` would have prevented it. That section must stay short (under 200 words): propose at most one edit per check-in, and make it replace or tighten an existing line rather than add one.
   - Workflow, what worked: decisions answered in one reply; proposals adopted with little change; a cheap test that changed the plan; an error caught before it reached the user; earlier work found through LOG; volume cut while the results held; a STRATEGY uncertainty resolved; an earlier `LESSON` followed that helped.
   - Workflow, what did not: work built before its scope was decided; decisions that waited long; volume added without results; earlier `LESSON`s not followed. A disproved conjecture or an abandoned approach is not waste if it taught something worth its cost; separate those from avoidable mistakes.

   Write zero to three `LESSON` entries to LOG, each with its evidence and the behavior it keeps or changes ("keep doing X" counts). Write none if nothing qualifies. The user may strike or add lessons. Prefer sharpening an existing instruction to adding one; propose a new rule (dotclaude's `user/CLAUDE.md` or `research.md`, or the project instructions) only for a failure that was consequential or likely to recur, and say which existing rule no longer helps if one doesn't. Rule changes become decisions in step 6. Forward each lesson about the workflow, rather than the project's content, with `/workflow-lesson` (or by following its `SKILL.md` by hand).

   **Harvest**, only in the repo that holds the workflow rules (its project instructions name the LOGs to read and the word caps). Grep the LESSON entries in those LOGs stamped after the date of this repo's last `checkin-*` tag, skipping those already in this LOG, and group them by theme. Propose a rule change only for a theme found in two or more repos, or a costly failure the user names, written as one principle rather than one rule per lesson; each change replaces or tightens text within the caps. Also list, as candidates for removal, rules that no lesson or user correction since the last harvest bears on. These go to step 6.
4. **Clean up.** Delete obsolete intermediates nothing current cites (review reports whose findings were applied, check scripts only they use, superseded drafts, finished plans) without asking: move any caveat into a living file first, `git rm` them, and list them in the commit message. Only a deletion that could lose information becomes a decision in step 6. If permissions block the deletion, add the command to STATUS as a task for the user.
5. **Strategy.** First, a fresh-context reader given STRATEGY, STATUS and the period's main outputs asks whether the work still answers the paper's question, and whether each premise traces to a decision of the user or to a source. Then draft any change to STRATEGY that the period's results call for (bets, uncertainties and their ranking, what is settled, target).
6. **Decide.** Put all decisions to the user in one numbered yes/no list, at most five, each with a recommendation, ordered by consequence: research direction and STRATEGY first, then changes to how Claude works, then anything administrative. Anything beyond five stays in STATUS. Wait for one reply. Apply what the user approves and LOG each decision in their words.
7. **Close.** Rewrite STATUS to one screen, with its "Last period" block (goals, done, next) for the period just closed, and update plan statuses. Write the kickoff prompts for the next sessions into a plan or STATUS and point to them from STATUS "How to resume". Commit (the message says what changed and points to LOG), then tag once: `checkin-N` (next number), or `checkin-YYYY-MM-DD` if the project has no numbered tags. Do not push.

Report in at most 300 words: the decision list first, then the lessons recorded, then what changed.

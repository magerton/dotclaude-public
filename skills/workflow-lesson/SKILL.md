---
name: workflow-lesson
description: Forward a LESSON about the research workflow (how the agent and the user work together, not the project's content) from a project to the LOG.md of the setup repo that holds the workflow rules, and commit that one file there. Used by /checkin; also when the user asks to send a lesson to the workflow log.
argument-hint: "[lesson text]"
---

# Workflow lesson

Written by Claude (AI), for @magerton.

The setup repo holds the user's workflow rules (`research.md`, `user/CLAUDE.md`, the skills). Its `LOG.md` collects workflow lessons from every project, so a check-in there can promote a recurring one into the rules. A workflow lesson is about how the work is done: how questions reach the user, how work is sequenced, reviewed, delegated or recorded. A lesson about the project's content (an estimator, a proof, a dataset) stays in the project's LOG only.

Lesson: $ARGUMENTS (if empty, the workflow lesson the conversation has just identified; if there is none, ask the user for it).

1. **Find the setup repo.** This skill is a link into it: resolve the `SKILL.md` you are reading and go two levels up, e.g. `setup="$(cd "$(dirname "$(realpath ~/.claude/skills/workflow-lesson/SKILL.md)")/../.." && pwd)"` (another agent may read it as `.dotclaude/skills/workflow-lesson/SKILL.md`). If `$setup` has no `LOG.md`, offer to create one from its `templates/LOG.md`. Stop and tell the user if `$setup` is not a git repo with `bin/log-entry`, or if it is a clone the user pulls from rather than maintains (for example `.dotclaude` linked to a public copy): lessons go to whoever maintains the rules.
2. **Same repo.** If the current project is the setup repo, record the lesson in its LOG with `bin/log-entry` and stop.
3. **Write one line**: what happened, the evidence (the user's words in quotes where they matter, a commit or a file), and the behavior it keeps or changes. Start it with the source repo in brackets, `[<repo>]`. Check that the line is not already in the setup LOG.
4. **Append.** Note whether the setup LOG has uncommitted changes (`git -C "$setup" diff --quiet HEAD -- LOG.md`). Then run `"$setup/bin/log-entry" --file "$setup/LOG.md" LESSON "[<repo>] <text>"`; in a shared repo, add `--handle @<user>`. If the project's own LOG lacks the lesson, append it there too.
5. **Commit only LOG.md**, and only if it had no uncommitted changes before step 4 (otherwise another session's lines would be swept in; leave it and say so): `git -C "$setup" commit --only LOG.md -m "LOG: workflow lesson from <repo>"`, with the attribution lines the session's instructions require. `--only` leaves anything else staged there untouched. Do not push.
6. **Report** the line written, and whether it was committed and on which branch (`git -C "$setup" branch --show-current`).

---
name: catchup
description: Catch the user up after time away from a session - what this session did, where it sits in the overall task, what is pending, what comes next. Read-only and short. Use when the user asks to be caught up, what we accomplished, where things stand, or what we were doing.
argument-hint: "[focus]"
---

# Catch up

Written by Claude (AI), for @magerton.

The user has been away and has forgotten the thread. Reorient them in under a minute of reading. Change nothing: no edits, commits or LOG entries.

Focus, if any: $ARGUMENTS

1. **Start from the conversation.** It is the main source: the goal, what was done, what is half-done, what the user was asked. If it holds no earlier work, say so in one line and answer from the repo alone.
2. **Check the repo once** for what the conversation cannot show (another session's commits, IDE edits, uncommitted changes), in one Bash call: `top="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; git -C "$top" status --short 2>/dev/null | head -20; git -C "$top" log --oneline -10 2>/dev/null; head -40 "$top/STATUS.md" 2>/dev/null`. If the overall goal is still unclear, read one more file (STRATEGY.md, the active plan, or README.md), no more. Check each background job this conversation started once, with the tool that started it or `ps -p <pid>`. If the context was compacted, trust the repo on files and commits, and the summary on decisions and what the user said.
3. **Answer** in at most 200 words plus the decisions, in this order:
   - **Goal**: the overall task, and where this session's work sits in it (one or two lines).
   - **Done this session**: results, not the narrative of the work, one line each, with a link to the file or commit.
   - **In progress**: work half-done, uncommitted changes, background jobs and whether they are still running. Last line: anything in the repo this session did not do (commits from another session, edits in the IDE).
   - **Waiting on you**: each open decision restated in full: what is decided, the options and their consequences, the recommendation and why. Omit the heading if there are none.
   - **Next**: the next step, and whether it needs the user.

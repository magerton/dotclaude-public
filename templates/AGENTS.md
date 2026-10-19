# <project name>

<One paragraph: what the project is, its main data and methods, who works on it.>

This file is the instructions for every coding agent. Codex reads it directly; `CLAUDE.md` (Claude Code) and `GEMINI.md` (Gemini CLI) each contain one line, `@AGENTS.md`.

## Read at session start

1. The working rules, through the gitignored link `.dotclaude` to a clone of `dotclaude-public` (`ln -s /path/to/dotclaude-public .dotclaude`). Read each file in full unless its content is already in your context:
   - `.dotclaude/user/CLAUDE.md`: writing rules, and the rules for `STATUS.md`, `STRATEGY.md` and `LOG.md`.
   - `.dotclaude/research.md`: research working rules (research projects only).

   If `.dotclaude` is missing, help the user set it up before other work.
2. `STATUS.md`, then `STRATEGY.md`. Grep `LOG.md` for a topic before starting work on it.

## Records

- `STATUS.md`, `STRATEGY.md`, `LOG.md` at the root.
- Results folder: `<work/>` (memos and analyses, `YYYY-MM-DD-<topic>.md`, with Date/Status/Summary headers). Plans: `plans/`.
- `scratch/` (at any level): throwaway output; gitignored.

<For a repo shared by several people: tag each LOG entry with the author's GitHub handle after the stamp (`YYYY-MM-DD-HHh-MMm @handle TAG text`), name the person each STATUS question is for, and say who may approve a change to STRATEGY.>

## Repo rules

- <What must never be committed (data, credentials), and where data lives.>
- <Languages and tools for each task.>

## This file

Current state only. Edit it when a fact in it becomes false. Results, dates and strategy go in `STATUS.md` and `STRATEGY.md`.

<Add to .gitignore: `.dotclaude`, `CLAUDE.local.md`, `scratch/`.>

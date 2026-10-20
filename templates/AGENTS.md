# <project name>

<One paragraph: what the project is, its main data and methods, who works on it.>

This file is the instructions for every coding agent. Codex reads it directly; `CLAUDE.md` (Claude Code) and `GEMINI.md` (Gemini CLI) each contain one line, `@AGENTS.md`.

## Read at session start

1. The working rules, through the gitignored link `.dotclaude` to a clone of `dotclaude-public` (`ln -s /path/to/dotclaude-public .dotclaude`). Read each file in full unless its content is already in your context:
   - `.dotclaude/user/CLAUDE.md`: writing rules, and the rules for `STATUS.md`, `STRATEGY.md` and `LOG.md`.
   - `.dotclaude/research.md`: research working rules (research projects only).

   If `.dotclaude` is missing, clone the public rules into it: `git clone --depth 1 https://github.com/magerton/dotclaude-public .dotclaude`. If git has no network access, read the files from `https://raw.githubusercontent.com/magerton/dotclaude-public/main/`. If neither works, tell the user before other work.
2. `STATUS.md`, then `STRATEGY.md`. Grep `LOG.md` for a topic before starting work on it.

## Records

- `STATUS.md`, `STRATEGY.md`, `LOG.md` at the root.
- Results folder: `<work/>` (memos and analyses, `YYYY-MM-DD-<topic>.md`, with Date/Status/Summary headers). Plans: `plans/`.
- `scratch/` (at any level): throwaway output; gitignored.

<For a repo shared by several people: a "Team" table (name, GitHub handle, role). The rules in `.dotclaude/user/CLAUDE.md`, "Shared repos", then apply.>

## Repo rules

- <What must never be committed (data, credentials), and where data lives.>
- <Languages and tools for each task.>

## This file

Current state only. Edit it when a fact in it becomes false. Results, dates and strategy go in `STATUS.md` and `STRATEGY.md`.

<Add to .gitignore: `.dotclaude`, `CLAUDE.local.md`, `scratch/`.>

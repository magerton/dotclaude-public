# dotclaude-public

Mark Agerton's working rules for research with coding agents (Claude Code, Codex, Gemini CLI). They are copied here from time to time from the repo where Mark keeps his own configuration.

- `user/CLAUDE.md`: writing rules, and rules for long projects kept in `STATUS.md`, `STRATEGY.md` and `LOG.md`.
- `research.md`: research working rules.
- `templates/`: starting files for a project: `AGENTS.md` (agent instructions that read these rules), `CLAUDE.md` and `GEMINI.md` (each imports `AGENTS.md`, so Claude Code, Codex and Gemini CLI read the same instructions), `STATUS.md`, `STRATEGY.md`, `LOG.md`.

"The user" in these files is the person running the agent session.

Use in a project: clone this repo anywhere, link it into the project root (`ln -s /path/to/dotclaude-public .dotclaude`, gitignored), and have the project's agent instructions read `.dotclaude/user/CLAUDE.md` and `.dotclaude/research.md`. To start a project, copy the files in `templates/` into its root and fill in the `<...>` parts. Claude Code users may instead link `user/CLAUDE.md` to `~/.claude/CLAUDE.md`, which applies it to all projects.

Changes are made at the source and copied here, so pull requests to this repo are not merged.

License: MIT (`LICENSE`).

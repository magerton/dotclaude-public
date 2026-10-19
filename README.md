# dotclaude-public

Mark Agerton's working rules and Claude Code skills for research with coding agents (Claude Code, Codex, Gemini CLI). They are copied here from time to time from the repo where Mark keeps his own configuration.

- `user/CLAUDE.md`: writing rules, and rules for long projects kept in `STATUS.md`, `STRATEGY.md` and `LOG.md`.
- `research.md`: research working rules.
- `templates/`: starting files for a project: `AGENTS.md` (agent instructions that read these rules), `CLAUDE.md` and `GEMINI.md` (each imports `AGENTS.md`, so Claude Code, Codex and Gemini CLI read the same instructions), `STATUS.md`, `STRATEGY.md`, `LOG.md`.
- `skills/`: Claude Code skills (below), installed with `install-skills.sh`.

"The user" in these files is the person running the agent session.

## Use in a project

Clone this repo anywhere, link it into the project root (`ln -s /path/to/dotclaude-public .dotclaude`, gitignored), and have the project's agent instructions read `.dotclaude/user/CLAUDE.md` and `.dotclaude/research.md`. To start a project, copy the files in `templates/` into its root and fill in the `<...>` parts. Claude Code users may instead link `user/CLAUDE.md` to `~/.claude/CLAUDE.md`, which applies it to all projects.

**Permissions through the link.** `.dotclaude` points outside the project folder, and Claude Code limits shell commands to the project folder. What may happen: the agent reads `.dotclaude/research.md` with its file-reading tool, but `ls`, `grep` or `cat` on `.dotclaude/...` asks for permission or is refused, and the agent may say it cannot list the folder. The rules still load if the agent reads the files. To stop the prompts, approve them, or give Claude Code the real folder: type `/add-dir /path/to/dotclaude-public` in a session, or add the path to `permissions.additionalDirectories` in the project's `.claude/settings.local.json`. A Claude Code `@` import from outside the project also loads only after a one-time approval, so project instructions should tell the agent to read the files itself if their content is not in context (`templates/AGENTS.md` does).

## Skills

Skills are folders with a `SKILL.md` that Claude Code loads from `~/.claude/skills/` (all projects) or a project's `.claude/skills/`. Invoke most by typing `/<name>`; Claude also uses some on its own when the task matches, and `build-makefile` only that way.

```sh
./install-skills.sh                  # link every skill into ~/.claude/skills
./install-skills.sh checkin compile  # only these
rm ~/.claude/skills/<name>           # remove one
```

The script makes links, so `git pull` here updates the installed skills. It moves an existing skill of the same name to `~/.claude/skills-backup/` (never deletes it), and changes nothing else in `~/.claude`. Other agents may read the same `SKILL.md` format; that is untested here.

| Skill | What it does | Needs | Caveats |
|---|---|---|---|
| `checkin` | Check-in for a long project: records missing findings in LOG, writes up to three LESSON entries, deletes obsolete intermediates, drafts STRATEGY changes, asks up to five decisions, rewrites STATUS, commits and tags. Only when typed. | A repo with `STATUS.md`, `STRATEGY.md`, `LOG.md` | Deletes files it judges obsolete without asking (listed in the commit message, recoverable from git). Commits and tags; never pushes. It may propose edits to these rules; send those to whoever maintains your copy of the rules rather than editing a clone you pull from. |
| `compile` | Builds a LaTeX document with `latexmk`, parses the log, suggests fixes; hands missing citations to `fix-latex-citations`. | A TeX distribution with `latexmk` (and `biber` for biblatex) | If a build fails it cleans and retries; the full clean (`latexmk -C`) deletes the PDF. The biber note is for Claude Code's sandbox. |
| `latexdiff` | PDF of a `.tex` file's changes against a git commit; full mode marks changed table cells and changed parameter-macro values and writes a table report; quick mode (`-m opaque`) shows tables as blocks. | git, `tar`, `latexdiff`, `latexmk`, `latexpand`, `python3`, `perl`; bibtex or biber | Reads only the old commit's text files from git into a temporary folder (megabytes, even in large repos); no checkout, no copy of the working tree. Compiles from the target's folder with `latexmk -outdir`, so no build files land in the repo. Writes `<date>-diff-vs-<ref>.{tex,pdf}`, `-table-values.txt` and, if figures were deleted since the old commit, `-figs/` (fetched from git) next to the target, replacing earlier outputs of the same name; consider gitignoring `*-diff-vs-*`. The manual fixes use BSD `sed -i ''`; on Linux use `sed -i`. |
| `flatten` | One self-contained `.tex` (inputs and bibliography inlined, `\todo` notes removed) for services such as refine.ink. | `latexpand`, `python3`, a fresh `.bbl` | Does not remove bolded coauthor notes; check the output before sending it to any outside service. |
| `build-makefile` | Builds a replication packet's Makefile one missing dependency at a time: finds the blocker with `gmake -n`, copies or writes the script, adds the rule, commits. Used by Claude when `gmake` reports "No rule to make target"; not invoked by typing. | GNU make 4.3+ (`gmake` on macOS), git; written for R and Stata packets | Copies scripts in from source repos and commits as it goes. Assumes a `data-intermediate/` and `R/` layout; adapt to yours. |
| `makefile-runtime-debug` | Diagnoses a packet where `gmake` runs but scripts fail or targets rebuild: dry runs, `--debug=why`, log reading, common R and Stata errors. | GNU make 4 (`gmake` on macOS) | Says never to touch files or add stamp files before finding the cause. Examples use R and Stata paths; adapt to yours. |
| `zotero` | Looks up items in your Zotero library: existence, cite key, metadata, abstract, notes. | Zotero desktop and the `zotero-mcp` server (<https://github.com/54yyyu/zotero-mcp>) registered in Claude Code as `zotero` | Assumes Better BibTeX keys of the form `[author][year][firstword]`; adjust if yours differ. Cannot add items. |
| `fetch-zotero-pdf` | Returns one passage (theorem, definition, quote) from a paper's full text, in a separate context. | As `zotero`; reads `~/Zotero/storage` if the full text is not indexed | Allow reads of `~/Zotero/storage` or expect a permission prompt. |
| `fix-latex-citations` | Finds undefined cite keys in a LaTeX log, searches Zotero for each, and reports fixes. | As `zotero` | Reports only; does not edit the `.tex` or `.bib`. |

The skills run shell commands and edit files. Read a skill before you rely on it.

## License and changes

MIT (`LICENSE`). Changes are made at the source and copied here, so pull requests to this repo are not merged.

Written by Claude (AI) for Mark Agerton.

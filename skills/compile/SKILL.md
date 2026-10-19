---
name: compile
description: Compile LaTeX documents with latexmk, identify errors, and suggest fixes. Can search Zotero for missing citations.
argument-hint: "[main.tex | clean | Clean]"
---

# LaTeX Compilation

Compile LaTeX documents, parse errors, and suggest fixes.

**Project settings first.** If the repo has `.claude/skills/compile/SKILL.md`, read it. Its
defaults (target file, engine, known warnings) take precedence over the defaults here. The
project's `CLAUDE.md` may also name the build command.

## Usage

```
/compile                           # Compile main.tex
/compile paper/main.tex            # Compile a specific file
/compile clean                     # Clean auxiliary files (latexmk -c)
/compile Clean                     # Clean all including PDF (latexmk -C)
```

## Instructions

**Important**: Provide status updates to the user before each step so they know what's happening.

### 1. Determine Target

Use the file given as the argument. With no argument, use `main.tex`. If `main.tex` does not
exist, use the default named in the project's `.claude/skills/compile/SKILL.md` or `CLAUDE.md`;
failing that, ask the user.

If argument is `clean` or `Clean`, run cleanup instead of compilation.

### 2. Run Compilation

**Important**: Always compile from within the directory containing the `.tex` file so LaTeX can find local class files (e.g., a journal `.cls`).

```bash
# Compile (from the directory containing the .tex file)
cd <directory> && latexmk -pdf <filename>

# Example for paper/main.tex:
cd paper && latexmk -pdf main.tex

# Clean auxiliary files only (also from within directory)
cd <directory> && latexmk -c <filename>

# Clean all including PDF
cd <directory> && latexmk -C <filename>
```

**Bibliography.** If every citation comes out undefined, biber failed: run `biber <name>` directly and check its exit code, not only the LaTeX log. In Claude's sandboxed shell biber can crash loading its unpacked cache from the system temp folder (Unicode::UCD); run it as `TMPDIR=<scratchpad>/partmp PAR_GLOBAL_TMPDIR=<scratchpad>/partmp biber <name>`, then pdflatex twice. Builds in the user's editor are not affected.

### 3. Handle Compilation Failures

If compilation fails with errors that suggest corrupted auxiliary files:
- "Emergency stop" or infinite recompilation loops
- Cross-reference errors that persist after multiple runs
- `.aux` file parse errors

**Auto-clean and retry**:
```bash
latexmk -c <target>   # Clean aux files
latexmk -pdf <target> # Retry compilation
```

If still failing after clean, try full clean:
```bash
latexmk -C <target>   # Clean all including PDF
latexmk -pdf <target> # Retry
```

### 4. Parse Output

Check the `.log` file for errors. Common patterns:

**Missing citations** (search Zotero):
```
LaTeX Warning: Citation `smith2023example' on page 5 undefined
Package natbib Warning: Citation `jones2022paper' on page 3 undefined
Package biblatex Warning: Citation 'smith2023' on page 5 undefined
```

**Undefined references**:
```
LaTeX Warning: Reference `fig:example' on page 2 undefined
```

**Syntax errors**:
```
! Undefined control sequence.
l.42 \badcommand
```

**Author undefined warnings** (natbib with a numeric `.bst`, e.g. PNAS):
```
Package natbib Warning: Author undefined for citation`somekey'
```
This occurs when using `\citet{}` with a numeric citation style such as PNAS. The pnas-new.bst doesn't embed author info in `\bibitem` entries, so natbib can't extract author names for `\citet`. The citation will render as **bold cite key** instead of "Author [#]".

**Fix**: Replace `\citet{key}` with `Author \citep{key}` (explicit author + parenthetical cite).

Report a list of these to the user but don't fix.

### 5. Handle Missing Citations

If the log contains undefined citation warnings:

Tell the user: `Found X missing citations. Invoking /fix-latex-citations...`

Then invoke the fix-latex-citations skill:

```
/fix-latex-citations <log-file-path>
```

This delegates citation resolution to the specialized skill, which will:
- Parse all missing cite keys from the log
- Search Zotero for each
- Generate an actionable report (found vs not found)

### 6. Report Results

Provide a summary:

```
## Compilation Result: SUCCESS/FAILED

### Errors (if any)
- Line 42: Undefined control sequence \badcommand
  → Suggestion: Check spelling or add package

### Warnings
- 3 undefined references
- 5 missing citations → invoking /fix-latex-citations
- 2 "Author undefined" warnings (numeric-style \citet issue) → list affected citations

### Actions Needed
1. Fix undefined control sequence on line 42
2. [Citation actions reported by /fix-latex-citations]
```

## Notes

- Always use `latexmk` commands, never `rm` for cleanup
- The log file is at `<target-basename>.log` in same directory as target
- For detailed Zotero searches, can use semantic search for conceptual matches

---
name: latexdiff
description: Generate latexdiff PDFs comparing a .tex file (default main.tex) against a git commit. Full mode marks changes inside tables and in same-name macro values (e.g. Stata/Julia parameter files) and writes a per-table value report; quick mode uses latexdiff-vc and shows tables as opaque blocks.
argument-hint: "<commit> [file.tex] [output-name] [quick]"
---

# LaTeX Diff Generation

Generate highlighted-change PDFs of a `.tex` file against a git ref.

**Project settings first.** If the repo has `.claude/skills/latexdiff/SKILL.md`, read it.
Its defaults (target file, macro files, excludes, its own scripts, known workarounds) take
precedence over the defaults here.

`SKILLDIR` below is this skill's folder (usually `~/.claude/skills/latexdiff`). One workflow below also uses the `flatten` skill, expected at `$SKILLDIR/../flatten`.

## Usage

```
/latexdiff abc1234                          # Diff main.tex vs commit abc1234
/latexdiff abc1234 paper/main.tex           # Diff paper/main.tex vs commit abc1234
/latexdiff abc1234 main.tex my-diff         # Custom output name (produces my-diff.tex/.pdf)
/latexdiff abc1234 main.tex quick           # Quick mode
/latexdiff HEAD~3                           # Diff vs 3 commits ago
/latexdiff main                             # Diff vs branch 'main'
```

## Full mode (default)

Use full mode unless the user says "quick" or the file is not in a git repo. It marks
cell-level table changes and same-name macro value changes, and writes a table value report.
Run it from anywhere inside the repo:

```bash
$SKILLDIR/scripts/make-latexdiff-full.sh [-f FILE] [-m auto|marked|opaque] [-o OUTNAME] \
    [-p MACROFILE]... [-x EXCLUDE]... <ref>
```

- `-f`: target, relative to the repo root. Default `main.tex`.
- `-p`: files of `\newcommand{\Foo}{value}` definitions whose values should be diffed
  (auto-generated numbers from Stata, Julia, etc.). Repeatable. Find candidates with
  `grep -l '\\newcommand' $(git ls-files '*.tex')` and the `\input`s in the preamble; ask
  the user if unsure. With no `-p`, macro value changes are not shown.
- `-x`: extra `rsync --exclude` patterns for large folders the build does not need
  (e.g. `docs/`, `submission/`). Repeatable.
- Default output name: `YYYY-MM-DD-diff-vs-<short>`. Outputs go in the target's directory:
  `<name>.pdf`, `<name>.tex`, and `<name>-table-values.txt`.
- Scratch dir: `$SCRATCH_DIR` (default `${TMPDIR:-/tmp}/latexdiff`). In a sandboxed session, set
  `SCRATCH_DIR` to the session scratchpad. The OLD worktree is removed on exit; the build copy of the
  repo (without `.git` and `data/`; add `-x` for other large or licensed folders) is deleted after a
  successful run and kept on failure.
- `auto` (default) tries marked tables and falls back to opaque tables if LaTeX errors remain.
- Report to the user: the table mode used, the error count, page count, and the SUMMARY
  line of the table report (tables identical / changed / added / dropped). Read the CHANGED
  section of the report and flag any table that changed unexpectedly.

Scripts (in `scripts/`):
- `make-latexdiff-full.sh`: the driver.
- `latexdiff-expand-macros.py`: expands plain-literal parameter macros to values.
- `latexdiff-unwrap-adjustbox.py`: unwraps `\adjustbox{opts}{...}` commands.
- `latexdiff-table-compare.py`: per-table value report, tables matched by nearest `\label`.

### Why tables break latexdiff, and the fixes

latexdiff treats a `tabular` as text and wraps changed bits in `\DIFadd`/`\DIFdel`. Four
things fight that. The full-mode script handles each one in the copies it diffs; the
committed sources are never touched.

1. **Rules.** `\toprule`, `\midrule`, `\bottomrule`, `\cmidrule`, `\cline`, `\hline`,
   `\addlinespace` and `\specialrule` expand to `\noalign`, which is legal only at a row
   boundary. When latexdiff edits a row, a diff marker or a row moved into a `%DIFDELCMD`
   comment leaves the rule mid-row → `Misplaced \noalign`, `Missing \cr`. Rules carry no
   data, so **strip them** before diffing. The diff PDF has no horizontal rules.
2. **`\multicolumn` must be the first token in its cell.** It works through `\omit`, which is
   legal only right after `&`, `\\`, or the tabular preamble. With `--graphics-markup=both`,
   `\DIFaddbeginFL`/`\DIFaddendFL` are not empty, so a marker in front of `\multicolumn` →
   `Misplaced \omit`. Fix: move the marker before the preceding `\\` or `\begin{tabular}{...}`.
3. **Tables inside a command argument.** latexdiff does not mark inside arguments, so a
   table wrapped in `\adjustbox{max totalsize=...}{% ...}` is
   diffed as one block: old commented out, new shown with no markup. Fix: unwrap the command
   form. `\begin{adjustbox}...\end{adjustbox}` (Stata tables) is fine as is.
4. **Same-name macro values.** latexdiff diffs source tokens. If `\Foo` keeps its name but
   its value changes in a macro file, nothing is marked. Fix: expand
   plain-literal macros to their values (OLD values in the OLD doc, NEW in the NEW doc) in the
   document body. Derived macros defined with `\fpeval{...}` or other commands
   are not expanded, so a value change in one of them shows only if its inputs appear in the text.

Other notes:
- Tables that lost or gained columns compile after fixes 1–2;
  latexdiff falls back to a block diff for restructured rows. The value report covers them.
- The value report keys a table by the nearest `\label` *before* its `tabular`. A table whose
  `\label` sits after the tabular is reported under the preceding label (often a section).
- Line matching in the report is row-based; an inserted row can make nearby rows look shifted.
  The SUMMARY counts and the identical-table list are exact.
- A figure whose image bytes changed under the same filename shows no diff. Check with
  `git diff --stat <ref> -- <figure folders>`.

## Quick mode

Use when the user asks for "quick", or as a fallback if full mode fails. Tables are opaque blocks
(new version shown, no markup) and same-name macro value changes are not shown.

## Quick-mode instructions

**Important**: Provide status updates to the user before each step.

### 1. Parse Arguments

Arguments are positional. Use `git rev-parse` to disambiguate commits from filenames.

- **1 arg**: `<ref>` — diff `main.tex` (default) vs that git ref
- **2 args**: `<ref> <file>` — diff specified file vs that ref
- **3 args**: `<ref> <file> <output-name>` — diff with custom output name

A "ref" is anything `git rev-parse` resolves: commit hash, `HEAD~N`, branch name, tag.

**Disambiguation**: If an argument could be both a ref and a filename (e.g., `main`), run `git rev-parse --verify <arg> 2>/dev/null`. If it resolves, treat as a ref. If not, treat as a filename. If truly ambiguous, ask the user.

Default file: `main.tex`
Default output name: `YYYY-MM-DD-diff-vs-<short-ref>.tex` (today's date, first 7 chars of resolved commit)

### 2. Validate Inputs

```bash
# Resolve the ref to a short hash (also validates it exists)
git rev-parse --short <ref>

# Get the commit message for the report
git log -1 --format='%s' <ref>

# Verify the tex file exists in the working directory
ls <file>

# Verify the tex file existed at the old commit
git show <ref>:<file> > /dev/null 2>&1

# Check for uncommitted changes and note in output
git status --short
```

If validation fails, report the error and stop. If the working directory is dirty, note this in the final report — the diff compares against the **working directory**, not HEAD, so uncommitted changes will be included.

### 3. Generate Diff

Run `latexdiff-vc` from the project root. The `--flatten` flag expands all `\input{}` files before diffing. The `--add-to-config` flag extends (not replaces) the default PICTUREENV to also protect tabular environments.

```bash
latexdiff-vc --git --flatten --force \
  -V --graphics-markup=both --encoding=utf8 \
  --add-to-config="PICTUREENV=(?:tabular|longtable|supertabular|threeparttable)[\w\d*@]*" \
  --append-mboxsafecmd="num,qty,numrange,qtyrange,SI,fpeval" \
  -r <ref> \
  <file> 2>&1 | tee /tmp/latexdiff-output.log
```

The `--append-mboxsafecmd` line tells latexdiff to wrap siunitx and fpeval commands in `\mbox{}` when they appear inside `\DIFadd{}`/`\DIFdel{}` blocks, preventing nested-brace breakage.

Capture the output — `latexdiff-vc` prints the generated filename on its last line:
```bash
# Extract auto-generated filename from latexdiff-vc output
DIFFFILE=$(grep '^Generated difference file' /tmp/latexdiff-output.log | sed 's/Generated difference file //')
```

Rename to the desired output name:
```bash
mv "$DIFFFILE" <output-name>.tex
```

### 4. Attempt compilation

use `latexmk -pdf`. If no errors, stop. Else identify errors and see if they match patterns below.

### 5. Fix Compilation Errors

If compilation succeeded, skip to step 7. Otherwise, check the `.log` for the first `!` error and apply the relevant fix below, then retry compilation. Repeat until clean or max 5 attempts.

**Note**: The sed patterns below use `[^}]*` which does not handle nested braces. For cite keys, labels, and control sequence names this is fine. For complex nested markup, restructure the diff markup manually (pull commands like `\num`, `\qty` outside the `\DIFadd{}`/`\DIFdel{}` wrappers).

#### Fix 1: `\csname` breakage
LaTeX requires plain text inside `\csname...\endcsname`. Markup there causes "Missing \endcsname inserted".

```bash
sed -i '' \
  -e 's/\\csname \\DIFadd{\([^}]*\)}/\\csname \1/g' \
  -e 's/\\csname \\DIFdel{\([^}]*\)}/\\csname \1/g' \
  <output>.tex
```

#### Fix 2: Markup inside citation commands
Strip `\DIFadd`/`\DIFdel` wrappers from inside any natbib cite variant:

```bash
sed -i '' \
  -e 's/\\cite\([a-zA-Z]*\){\\DIFadd{\([^}]*\)}}/\\cite\1{\2}/g' \
  -e 's/\\cite\([a-zA-Z]*\){\\DIFdel{\([^}]*\)}}/\\cite\1{\2}/g' \
  <output>.tex
```

This covers `\cite`, `\citep`, `\citet`, `\citealt`, `\citealp`, `\citeauthor`, `\citeyear`, `\Citep`, `\Citet`, etc.

#### Fix 3: Markup inside `\ref` / `\label`
```bash
sed -i '' \
  -e 's/\\ref{\\DIFadd{\([^}]*\)}}/\\ref{\1}/g' \
  -e 's/\\ref{\\DIFdel{\([^}]*\)}}/\\ref{\1}/g' \
  -e 's/\\label{\\DIFadd{\([^}]*\)}}/\\label{\1}/g' \
  -e 's/\\label{\\DIFdel{\([^}]*\)}}/\\label{\1}/g' \
  <output>.tex
```

#### Fix 4: siunitx commands (`\num`, `\qty`, `\SI`) with nested braces
The `--append-mboxsafecmd` flag should prevent this. If it still occurs, pull the siunitx command outside the diff wrapper: `\DIFadd{text} \num{value} \DIFadd{more text}` instead of `\DIFadd{text \num{value} more text}`.

#### Fix 5: float errors ("Not in outer par mode" / "Float lost")
Diff markup around `\begin{figure}` or `\begin{table}` breaks float placement. Remove the `\DIFaddbegin`/`\DIFaddend` markers surrounding the float.

### 6. Report Results

```
## Latexdiff Result: SUCCESS/FAILED

**Old**: <ref> → <short-hash> ("<commit message>")
**New**: working directory [DIRTY — includes uncommitted changes] or [clean]
**Output**: <output>.pdf (<N> pages)

### Fixes Applied
- [list any sed fixes or DIFnomarkup wraps applied]

### Warnings
- [any undefined citations in deleted text — expected and harmless]
- [any remaining non-fatal warnings]
```

Get page count with: `grep -c 'Output written' <output>.log` or `pdfinfo <output>.pdf | grep Pages`.

## Notes

- `latexdiff-vc --git --flatten` checks out the old revision into a local temp directory (no network access) and flattens all `\input{}` files before diffing
- The diff compares the old commit against the **working directory** (not HEAD) — uncommitted changes are included
- Undefined citations in deleted (strikethrough) text are expected and harmless — the old cite keys may no longer exist in the bib
- `--add-to-config` extends the default PICTUREENV (which already protects `picture`, `tikzpicture`, `DIFnomarkup`) to also protect tabular-family environments
- If `\input{}`ed files were added since the old commit, they appear as entirely new (added) text — this is correct behavior
- The `sed -i ''` syntax is macOS/BSD-specific; on Linux use `sed -i` (no empty string)
- **Files that `\input{../...}` from another directory** (e.g. a response letter that quotes
  paper sections): `latexdiff-vc --flatten` silently fails to expand `../` paths, and the
  changed text shows with no markup. Pre-flatten both versions with the `flatten` skill's
  newline-safe inliner, then diff the flats:

  ```bash
  git worktree add /tmp/old-<ref> <ref>
  python3 $SKILLDIR/../flatten/flatten_inputs.py /tmp/old-<ref>/<dir>/<file>.tex > <dir>/old-flat.tex
  python3 $SKILLDIR/../flatten/flatten_inputs.py <dir>/<file>.tex > <dir>/new-flat.tex
  cd <dir> && latexdiff --graphics-markup=both --encoding=utf8 \
    --add-to-config="PICTUREENV=(?:tabular|longtable|supertabular|threeparttable)[\w\d*@]*" \
    --append-mboxsafecmd="num,qty,numrange,qtyrange,SI,fpeval" \
    old-flat.tex new-flat.tex > <output>.tex
  latexmk -pdf <output>.tex   # then: git worktree remove /tmp/old-<ref>
  ```

---
name: latexdiff
description: Generate latexdiff PDFs comparing a .tex file (default main.tex) against a git commit. Full mode marks changes inside tables and in same-name macro values (e.g. Stata/Julia parameter files) and writes a per-table value report; quick mode shows tables as opaque blocks. Reads only the old commit's text files from git; nothing is checked out or copied.
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
    [-p MACROFILE]... <ref>
```

- `-f`: target, relative to the repo root. Default `main.tex`.
- `-p`: files of `\newcommand{\Foo}{value}` definitions whose values should be diffed
  (auto-generated numbers from Stata, Julia, etc.). Repeatable. Find candidates with
  `grep -l '\\newcommand' $(git ls-files '*.tex')` and the `\input`s in the preamble; ask
  the user if unsure. With no `-p`, macro value changes are not shown.
- Default output name: `YYYY-MM-DD-diff-vs-<short>`. Outputs go in the target's directory:
  `<name>.pdf`, `<name>.tex`, and `<name>-table-values.txt`.
- Cost: the old commit's text files only (`.tex`, `.sty`, `.cls`, `.bst`, `.bib`, ...), read from
  git with `git archive` into a temporary folder under `$SCRATCH_DIR` (default
  `${TMPDIR:-/tmp}/latexdiff`); under 3 MB in the repos tested, including one of 32 GB. No
  worktree, no copy of the working tree. The diff compiles from the target's folder with
  `latexmk -outdir`, so figures and `../` paths resolve as in a normal build and no build files
  land in the repo. Figures that exist only at the old commit are fetched one by one with
  `git show`; the delivered `.tex` points to them in the temporary folder, which is deleted
  after a successful run (kept after a failure, for debugging). In a sandboxed session, set
  `SCRATCH_DIR` to the session scratchpad.
- If this version fails on a document, `/latexdiff-old` is the previous version (copies the
  whole working tree; avoid in large repos).
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
(new version shown, no markup) and same-name macro value changes are not shown:

```bash
$SKILLDIR/scripts/make-latexdiff-full.sh -m opaque [-f FILE] [-o OUTNAME] <ref>
```

Do not use `latexdiff-vc --flatten`: it extracts the whole old commit with `git archive`, which
is gigabytes in large repos.

**Important**: Provide status updates to the user before each step.

Arguments are positional. Use `git rev-parse --verify <arg>` to tell a ref from a filename
(e.g. `main`); if truly ambiguous, ask. Default file `main.tex`; default output name
`YYYY-MM-DD-diff-vs-<short-ref>`. The diff compares the old commit against the **working
directory**, so uncommitted changes are included; say so in the report if `git status --short`
is not empty.

## Fixing compilation errors by hand

If the delivered `<output>.tex` still has LaTeX errors, apply the relevant fix below and
recompile from the target's folder without leaving build files there:
`latexmk -pdf -outdir="${TMPDIR:-/tmp}/ld-fix" <output>.tex`, then copy the PDF back. Repeat
until clean or 5 attempts.

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

- The diff compares the old commit against the **working directory** (not HEAD) — uncommitted changes are included
- Undefined citations in deleted (strikethrough) text are expected and harmless — the old cite keys may no longer exist in the bib
- `--add-to-config` extends the default PICTUREENV (which already protects `picture`, `tikzpicture`, `DIFnomarkup`) to also protect tabular-family environments
- If `\input{}`ed files were added since the old commit, they appear as entirely new (added) text — this is correct behavior
- The `sed -i ''` syntax is macOS/BSD-specific; on Linux use `sed -i` (no empty string)
- **Files that `\input{../...}` from another directory** (e.g. a response letter that quotes
  paper sections): `latexdiff-vc --flatten` silently fails to expand `../` paths, and the
  changed text shows with no markup. If the script's `latexpand` step has the same problem,
  pre-flatten both versions with the `flatten` skill's newline-safe inliner, then diff the flats.
  Extract only the old text files, not a worktree:

  ```bash
  mkdir -p /tmp/old-<ref> && git archive <ref> -- '*.tex' | tar -x -C /tmp/old-<ref>
  python3 $SKILLDIR/../flatten/flatten_inputs.py /tmp/old-<ref>/<dir>/<file>.tex > <dir>/old-flat.tex
  python3 $SKILLDIR/../flatten/flatten_inputs.py <dir>/<file>.tex > <dir>/new-flat.tex
  cd <dir> && latexdiff --graphics-markup=both --encoding=utf8 \
    --add-to-config="PICTUREENV=(?:tabular|longtable|supertabular|threeparttable)[\w\d*@]*" \
    --append-mboxsafecmd="num,qty,numrange,qtyrange,SI,fpeval" \
    old-flat.tex new-flat.tex > <output>.tex
  latexmk -pdf -outdir="${TMPDIR:-/tmp}/ld-fix" <output>.tex   # then: rm -rf /tmp/old-<ref>
  ```

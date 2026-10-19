---
name: flatten
description: Flatten a LaTeX document (default main.tex) into a single self-contained .tex file (all \input files and the bibliography inlined, \todo notes stripped) for submission to external services like refine.ink.
argument-hint: "[file.tex] [output-name.tex]"
---

# Flatten Paper for Submission

Produce a single-file version of the paper with all `\input`/`\include` files
inlined, the compiled bibliography embedded, and `\todo{}` notes removed.

Target: the `.tex` file given as the argument; default `main.tex`. Run from the target's
directory. Default output: `<target>-flattened.tex`. The steps below use `main`; substitute
the target's basename. If the repo has `.claude/skills/flatten/SKILL.md`, read it for
project-specific documents and workarounds.

`SKILLDIR` below is this skill's folder (usually `~/.claude/skills/flatten`).

## Steps

1. **Ensure a fresh `main.bbl` exists.** If missing or stale, compile first
   (see the `compile` skill): `latexmk -pdf main.tex`.

2. **Inline all `\input`s with the newline-safe helper, THEN latexpand.**
   Do NOT let latexpand expand `\input`s: it inlines files mid-line while
   keeping a bare `%` where comments were, so a file ending in `%` comments
   out the next `\input` on the same parent line. (This silently deleted a
   paragraph from a refine.ink submission: a section file had
   two `\input`s on one line, and the first input file ended with `%`.)

   ```bash
   python3 $SKILLDIR/flatten_inputs.py main.tex > main-flattened.tex
   latexpand --expand-bbl main.bbl main-flattened.tex > tmp.tex && mv tmp.tex main-flattened.tex
   ```

   `flatten_inputs.py` inlines recursively, always starting inlined content on
   a fresh line; the latexpand pass then only strips comments (desirable for
   external submission) and embeds the bibliography. Use `--keep-comments` if
   comments should survive.

3. **Strip `\todo` notes** with the brace-aware helper in this directory:

   ```bash
   python3 $SKILLDIR/strip_todos.py main-flattened.tex > tmp.tex \
     && mv tmp.tex main-flattened.tex
   ```

   This removes `\todo[opts]{...}` including nested braces. It does NOT remove
   bolded coauthor notes (`\textbf{Name: ...}` etc.) — grep for those, using the
   coauthors' first names (from the project's `CLAUDE.md`), and ask the user if
   any should also come out:

   ```bash
   grep -n 'textbf{\(Name1\|Name2\|Name3\)' main-flattened.tex
   ```

4. **Verify**: no `\input{` remains, and the file compiles standalone:

   ```bash
   grep -c '\\input{' main-flattened.tex   # expect 0
   pdflatex -interaction=nonstopmode -draftmode -halt-on-error main-flattened.tex
   ```

   Then clean up aux files: `rm -f main-flattened.{aux,log,out,toc,pdf}`.

## Biblatex documents

For documents that use **biblatex + biber** (not bibtex), do NOT use `--expand-bbl` or
`--biber` — latexpand dumps the biber `.bbl` (`\refsection`, `\entry`, ...) raw into
the preamble, where biblatex cannot read it, causing a fatal
"File ended while scanning use of ^^M" error.

Instead, flatten without bbl expansion and prepend a `filecontents*` block that
regenerates `\jobname.bbl` at compile time (biblatex then reads it normally):

```bash
doc=main   # target basename
python3 $SKILLDIR/flatten_inputs.py $doc.tex > body.tmp
latexpand body.tmp > b2.tmp && mv b2.tmp body.tmp
python3 $SKILLDIR/strip_todos.py body.tmp > b2.tmp && mv b2.tmp body.tmp
{ printf '\\begin{filecontents*}[overwrite]{\\jobname.bbl}\n'
  cat $doc.bbl
  printf '\\end{filecontents*}\n'
  cat body.tmp; } > $doc-flattened.tex
rm body.tmp
```

Requires a fresh `$doc.bbl` (compile the original with latexmk/biber first).
On compile, biblatex emits a benign "Please (re)run Biber" warning because the
`.bcf` is fresh; citations still resolve — verify with a two-pass pdflatex and
`grep -ci undefined` on the log (expect 0) and matching page count vs the
original PDF.

## Notes

- Figures remain external `\includegraphics` references; that is fine for
  text-analysis services. If a fully self-contained archive is needed,
  also collect the `figures/` files referenced in the flattened .tex.
- Flattened files are build artifacts; add `*-flattened.tex` to `.gitignore` if it is not there.

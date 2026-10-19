#!/usr/bin/env bash
# =============================================================================
# make-latexdiff-full.sh  (light: no checkout of the old commit, no copy of the repo)
# Light version written by Claude (AI) for Mark Agerton, 2026-10-19, from an earlier driver.
#
# latexdiff PDF of a .tex file (current working tree) vs a past git commit,
# WITH cell-level table markup, same-name macro value changes, and a table
# value-change report.
#
# Plain latexdiff mangles tables: every \toprule/\midrule/\bottomrule/\cline/
# \hline/\addlinespace expands to \noalign, which is legal only at a row boundary.
# When latexdiff edits a row, a following rule lands mid-row -> "Misplaced
# \noalign" / "Missing \cr". And \multicolumn must be the first token of its
# cell, but latexdiff puts \DIF...FL markers in front of it -> "Misplaced \omit".
#
# Cost: the old commit's TEXT files only (.tex .sty .cls .bst .bib ...), read from git
# objects with `git archive` into a temporary folder; no worktree, no copy of the working
# tree. The diff compiles from FILE's own folder (latexmk -outdir), so figures, .bib and
# class files resolve as in a normal build; build files go to the temporary folder.
# Figures that exist only at OLD_REF are fetched one by one with `git show`.
#
# Recipe (MODE=marked, the default via auto):
#   1. OLD text files from git (git archive of the matching paths) into $T/old;
#   2. flatten both docs with latexpand (OLD in $T/old, NEW in the working tree);
#   3. table value report from the UNSTRIPPED flats (faithful);
#   4. expand plain-literal parameter macros to values (OLD values into OLD doc,
#      NEW into NEW) so same-name value changes become visible text changes;
#   5. unwrap \adjustbox{opts}{...} commands (latexdiff won't mark inside command
#      arguments) and STRIP rule commands (formatting only; diff PDF has no rules);
#   6. latexdiff with tabular NOT in PICTUREENV;
#   7. inline OLD parameter macros as \providecommand (struck-out macros compile);
#   8. move \DIF...FL markers that precede \multicolumn out of the cell;
#   9. point \includegraphics at old-only figures fetched from git (delivered in
#      OUTNAME-figs/ next to the output, so the delivered .tex recompiles);
#  10. latexmk from FILE's folder with -outdir; if errors remain, fall back to opaque
#      tables (always compiles, shows only the NEW table).
#
# Usage (from anywhere inside the git repo):
#   make-latexdiff-full.sh [-f FILE] [-m MODE] [-o OUTNAME] [-p MACROFILE]... OLD_REF
#     OLD_REF   : git commit/tag/branch to diff against
#     -f FILE   : .tex file to diff, relative to repo root   (default: main.tex)
#     -m MODE   : auto | marked | opaque                     (default: auto)
#     -o OUTNAME: output basename                  (default: YYYY-MM-DD-diff-vs-<short>)
#     -p FILE   : macro-definition file, relative to repo root; repeatable. Plain-literal
#                 \newcommand{\Foo}{value} definitions in these files are expanded
#                 (default: none)
#   SCRATCH_DIR env var sets the scratch location (default: ${TMPDIR:-/tmp}/latexdiff).
#   The temporary folder is deleted after a successful run and kept on failure for debugging.
#
# Outputs (directory of FILE): OUTNAME.pdf, OUTNAME.tex, OUTNAME-table-values.txt
# Requires: git, tar, latexdiff, latexmk (+bibtex or biber), latexpand, python3, perl.
# =============================================================================
set -euo pipefail
export PATH="$PATH:/usr/bin:/bin:/usr/local/bin:/Library/TeX/texbin"   # fallbacks; the user's tools come first

MAIN="main.tex"; MODE="auto"; OUTNAME=""; PARAMS=()
while getopts "f:m:o:p:x:" opt; do
  case "$opt" in
    f) MAIN="$OPTARG" ;; m) MODE="$OPTARG" ;; o) OUTNAME="$OPTARG" ;;
    p) PARAMS+=("$OPTARG") ;; x) echo ">> -x is not needed (nothing is copied); ignored" >&2 ;;
    *) echo "usage: make-latexdiff-full.sh [-f FILE] [-m MODE] [-o OUTNAME] [-p MACROFILE]... OLD_REF" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
case "$MODE" in auto|marked|opaque) ;; *) echo "!! -m must be auto, marked or opaque (quick mode is -m opaque)" >&2; exit 2 ;; esac
OLD_REF="${1:?usage: make-latexdiff-full.sh [-f FILE] [-m MODE] [-o OUTNAME] [-p MACROFILE]... OLD_REF}"
SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(git rev-parse --show-toplevel)"
MAINDIR="$(dirname "$MAIN")"; MAINFILE="$(basename "$MAIN")"
[ -f "$REPO/$MAIN" ] || { echo "!! $REPO/$MAIN not found" >&2; exit 1; }
SHORT="$(cd "$REPO" && git rev-parse --short "$OLD_REF")"
OUTNAME="${OUTNAME:-$(date +%Y-%m-%d)-diff-vs-$SHORT}"
SCRATCH="${SCRATCH_DIR:-${TMPDIR:-/tmp}/latexdiff}"
HELPER="$SCRIPTDIR/latexdiff-table-compare.py"
EXPANDER="$SCRIPTDIR/latexdiff-expand-macros.py"
UNWRAP="$SCRIPTDIR/latexdiff-unwrap-adjustbox.py"
OLDFIGS="$SCRIPTDIR/latexdiff-old-figures.py"
LDCOMMON=( --graphics-markup=both --encoding=utf8 --append-mboxsafecmd="num,qty,numrange,qtyrange,SI,fpeval,unit" )

mkdir -p "$SCRATCH"; SCRATCH="$(cd "$SCRATCH" && pwd)"   # absolute, so later cd calls keep it
T="$(mktemp -d "$SCRATCH/$(basename "$REPO")-XXXXXX")"
OLD="$T/old"; B="$T/build"; mkdir -p "$OLD" "$B"
ok=0
cleanup () { if [ "$ok" = 1 ]; then rm -rf "$T"; else echo "!! kept $T for debugging" >&2; fi; }
trap cleanup EXIT
echo ">> OLD_REF=$OLD_REF ($SHORT)  FILE=$MAIN  MODE=$MODE  repo=$REPO  tmp=$T"

# --- 1. OLD text files from git objects (no checkout) -------------------------
( cd "$REPO" && git ls-tree -r -z --name-only "$OLD_REF" ) \
  | perl -0 -ne 'print if /\.(?:tex|sty|cls|bst|bib|bbx|cbx|lbx|def|cfg|clo|ltx|bbl)\0?$/i' > "$T/old-files"
for p in ${PARAMS[@]+"${PARAMS[@]}"}; do
  ( cd "$REPO" && git cat-file -e "$OLD_REF:$p" 2>/dev/null ) && printf '%s\0' "$p" >> "$T/old-files"
done
[ -s "$T/old-files" ] || { echo "!! no text files at $OLD_REF" >&2; exit 1; }
# Literal pathspecs: file names are paths, not patterns. pipefail: a git archive error stops the run.
( cd "$REPO" && GIT_LITERAL_PATHSPECS=1 OLDDIR="$OLD" xargs -0 bash -c 'set -o pipefail; git archive "$0" -- "$@" | tar -x -C "$OLDDIR"' "$OLD_REF" < "$T/old-files" )
[ -f "$OLD/$MAIN" ] || { echo "!! $MAIN not found at $OLD_REF" >&2; exit 1; }
echo "   old text files: $(tr -cd '\0' < "$T/old-files" | wc -c | tr -d ' '), $(du -sh "$OLD" | cut -f1)"
# --- 3. OLD-parameter shim ----------------------------------------------------
# A macro file that loads packages (a preamble) cannot be read after \begin{document};
# from such a file take only the plain-literal definitions. Copy other files whole.
{
  echo "% AUTO-GENERATED: OLD parameter macros as \\providecommand for struck-out deletions."
  for p in ${PARAMS[@]+"${PARAMS[@]}"}; do
    [ -f "$OLD/$p" ] || continue
    if grep -qE '\\(usepackage|documentclass|RequirePackage)' "$OLD/$p"; then
      perl -ne 'print "\\newcommand{\\$1}{$2}\n" while /\\newcommand\{\\([A-Za-z]+)\}\{([^{}\\]*)\}/g' "$OLD/$p"
    else
      cat "$OLD/$p"
    fi
  done | perl -pe 's/\\newcommand\b/\\providecommand/g'
} > "$B/old-params-shim.tex"

# --- 4. flatten both docs -----------------------------------------------------
# latexpand runs in FILE's directory (OLD: in $T/old). The diff later compiles from
# FILE's directory in the working tree, so relative paths resolve as in a normal build.
( cd "$OLD/$MAINDIR"  && latexpand "$MAINFILE" 2>/dev/null > "$B/old-flat.tex" )
( cd "$REPO/$MAINDIR" && latexpand "$MAINFILE" 2>/dev/null > "$B/new-flat.tex" )

# --- 5. table value report (unstripped flats) ---------------------------------
python3 "$HELPER" "$B/old-flat.tex" "$B/new-flat.tex" "$B/table-value-diff.txt" "$OLD_REF ($SHORT)"

# --- helpers -----------------------------------------------------------------
strip_rules () {
  perl -0777 -pe '
    s/\\(top|mid|bottom)rule\b(\[[^\]]*\])?//g; s/\\hline\b//g; s/\\morecmidrules\b//g;
    s/\\cmidrule\s*(\([^)]*\))?\s*\{[^}]*\}//g; s/\\cline\s*\{[^}]*\}//g;
    s/\\addlinespace\s*(\[[^\]]*\])?//g;
    s/\\specialrule\s*\{[^}]*\}\s*\{[^}]*\}\s*\{[^}]*\}//g;
  ' "$1" > "$2"
}
inject_shim () {  # inline the OLD macros before \begin{document}, so the delivered .tex needs no extra file
  SHIM="$B/old-params-shim.tex" perl -0777 -i -pe 'BEGIN { local $/; open my $f, "<", $ENV{SHIM} or die; $shim = <$f> } s/(\\begin\{document\})/$shim$1/ unless /AUTO-GENERATED: OLD parameter macros/' "$1"
}
compile () {
  python3 "$OLDFIGS" "$B/main-diff.tex" "$REPO" "$MAINDIR" "$OLD_REF" "$T/figs" >&2 || echo "!! old-figure step failed; deleted figures may be missing" >&2
  ( cd "$REPO/$MAINDIR" && TEXMFOUTPUT="$B" latexmk -pdf -interaction=nonstopmode -outdir="$B" "$B/main-diff.tex" > "$B/compile.log" 2>&1 || true )
}
fix_multicolumn () {
  # \multicolumn must be the FIRST token of its cell. Move \DIF...FL markers that sit
  # (a) between a row-end \\ and \multicolumn to before the \\, or
  # (b) between \begin{tabular}{spec} and \multicolumn to before \begin{tabular}.
  perl -0777 -i -pe '
    s/(\\\\)\s*((?:\\DIF(?:add|del)(?:begin|end)FL\s*)+)(\\multicolumn)/$2$1\n$3/g;
    s/(\\begin\{tabular\}\{[^\n]*\})\s*((?:\\DIF(?:add|del)(?:begin|end)FL\s*)+)(\\multicolumn)/$2$1\n$3/g;
  ' "$1"
}
errcount () { [ -f "$1" ] || { echo 999; return; }; grep -cE '^!' "$1" 2>/dev/null || true; }

build_marked () {
  OLDP=(); NEWP=()
  for p in ${PARAMS[@]+"${PARAMS[@]}"}; do OLDP+=("$OLD/$p"); NEWP+=("$REPO/$p"); done
  # set -e does not apply inside $(...), so each step reports failure as 999 errors.
  python3 "$EXPANDER" "$B/old-flat.tex" ${OLDP[@]+"${OLDP[@]}"} "$B/old-flat-exp.tex" >&2 || { echo 999; return; }
  python3 "$EXPANDER" "$B/new-flat.tex" ${NEWP[@]+"${NEWP[@]}"} "$B/new-flat-exp.tex" >&2 || { echo 999; return; }
  python3 "$UNWRAP" "$B/old-flat-exp.tex" "$B/old-flat-unwrap.tex" >&2 || { echo 999; return; }
  python3 "$UNWRAP" "$B/new-flat-exp.tex" "$B/new-flat-unwrap.tex" >&2 || { echo 999; return; }
  strip_rules "$B/old-flat-unwrap.tex" "$B/old-flat-norule.tex"
  strip_rules "$B/new-flat-unwrap.tex" "$B/new-flat-norule.tex"
  ( cd "$B" && latexdiff "${LDCOMMON[@]}" \
        --config="PICTUREENV=(?:picture|DIFnomarkup)[\w\d*@]*" \
        old-flat-norule.tex new-flat-norule.tex > main-diff.tex 2> latexdiff.stderr ) || { echo "!! latexdiff failed; see $B/latexdiff.stderr" >&2; echo 999; return; }
  inject_shim "$B/main-diff.tex"
  fix_multicolumn "$B/main-diff.tex"
  compile
  errcount "$B/main-diff.log"
}
build_opaque () {
  ( cd "$B" && latexdiff "${LDCOMMON[@]}" \
        --config="PICTUREENV=(?:picture|DIFnomarkup|tabular|longtable|threeparttable)[\w\d*@]*" \
        old-flat.tex new-flat.tex > main-diff.tex 2> latexdiff.stderr ) || { echo "!! latexdiff failed; see $B/latexdiff.stderr" >&2; echo 999; return; }
  inject_shim "$B/main-diff.tex"
  compile
  errcount "$B/main-diff.log"
}

# --- 6. choose mode (auto-fallback) ------------------------------------------
chosen=""; e=""
if [ "$MODE" = "marked" ] || [ "$MODE" = "auto" ]; then
  echo ">> building MARKED (inline tables) ..."
  e="$(build_marked)"; echo "   marked LaTeX errors: $e"
  [ "$e" = "0" ] && chosen="marked"
fi
if [ -z "$chosen" ] && [ "$MODE" != "marked" ]; then
  echo ">> building OPAQUE tables (fallback) ..."
  e="$(build_opaque)"; echo "   opaque LaTeX errors: $e"; chosen="opaque"
fi
[ -n "$chosen" ] || { echo "!! marked mode left $e errors; see $B/main-diff.log"; chosen="marked(with-errors)"; }
[ -f "$B/main-diff.pdf" ] || { echo "!! no PDF; see $B/compile.log" >&2; exit 1; }

# --- 7. deliverables ------------------------------------------------------------
cp "$B/main-diff.pdf"        "$REPO/$MAINDIR/$OUTNAME.pdf"
cp "$B/main-diff.tex"        "$REPO/$MAINDIR/$OUTNAME.tex"
if [ -d "$T/figs" ]; then   # old-only figures: deliver beside the output; point the .tex at them
  rm -rf "$REPO/$MAINDIR/$OUTNAME-figs"; cp -R "$T/figs" "$REPO/$MAINDIR/$OUTNAME-figs"
  FROM="$T/figs/" TO="$OUTNAME-figs/" perl -pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$REPO/$MAINDIR/$OUTNAME.tex"
  echo "   $REPO/$MAINDIR/$OUTNAME-figs/ (figures deleted since $SHORT)"
fi
cp "$B/table-value-diff.txt" "$REPO/$MAINDIR/$OUTNAME-table-values.txt"
ok=1
echo ">> DONE (table mode: $chosen)"
echo "   $REPO/$MAINDIR/$OUTNAME.pdf"
echo "   $REPO/$MAINDIR/$OUTNAME-table-values.txt"

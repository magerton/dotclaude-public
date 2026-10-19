#!/usr/bin/env bash
# =============================================================================
# make-latexdiff-full.sh
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
# Recipe (MODE=marked, the default via auto):
#   1. OLD in a git worktree; build in a scratch dir (repo stays clean);
#   2. rsync OLD-only files (deleted figures) into the build dir so
#      --graphics-markup=both can render both versions;
#   3. flatten both docs with latexpand;
#   4. table value report from the UNSTRIPPED flats (faithful);
#   5. expand plain-literal parameter macros to values (OLD values into OLD doc,
#      NEW into NEW) so same-name value changes become visible text changes;
#   6. unwrap \adjustbox{opts}{...} commands (latexdiff won't mark inside command
#      arguments) and STRIP rule commands (formatting only; diff PDF has no rules);
#   7. latexdiff with tabular NOT in PICTUREENV;
#   8. inject OLD parameter macros as \providecommand (struck-out macros compile);
#   9. move \DIF...FL markers that precede \multicolumn out of the cell;
#  10. latexmk; if errors remain, fall back to opaque tables (always compiles,
#      shows only the NEW table).
#
# Usage (from anywhere inside the git repo):
#   make-latexdiff-full.sh [-f FILE] [-m MODE] [-o OUTNAME] [-p MACROFILE]... [-x EXCLUDE]... OLD_REF
#     OLD_REF   : git commit/tag/branch to diff against
#     -f FILE   : .tex file to diff, relative to repo root   (default: main.tex)
#     -m MODE   : auto | marked | opaque                     (default: auto)
#     -o OUTNAME: output basename                  (default: YYYY-MM-DD-diff-vs-<short>)
#     -p FILE   : macro-definition file, relative to repo root; repeatable. Plain-literal
#                 \newcommand{\Foo}{value} definitions in these files are expanded
#                 (default: none)
#     -x PATTERN: extra rsync --exclude for the build copy; repeatable
#   SCRATCH_DIR env var sets the scratch location (default: ${TMPDIR:-/tmp}/latexdiff).
#   The build copy excludes data/ and is deleted after a successful run; it is kept on failure for debugging.
#
# Outputs (directory of FILE): OUTNAME.pdf, OUTNAME.tex, OUTNAME-table-values.txt
# Requires: git, latexdiff, latexmk (+biber), latexpand, rsync, python3, perl.
# =============================================================================
set -euo pipefail
export PATH="$PATH:/usr/bin:/bin:/usr/local/bin:/Library/TeX/texbin"   # fallbacks; the user's tools come first

MAIN="main.tex"; MODE="auto"; OUTNAME=""; PARAMS=(); EXTRA_EX=()
while getopts "f:m:o:p:x:" opt; do
  case "$opt" in
    f) MAIN="$OPTARG" ;; m) MODE="$OPTARG" ;; o) OUTNAME="$OPTARG" ;;
    p) PARAMS+=("$OPTARG") ;; x) EXTRA_EX+=(--exclude="$OPTARG") ;;
    *) echo "usage: make-latexdiff-full.sh [-f FILE] [-m MODE] [-o OUTNAME] [-p MACROFILE]... [-x EXCLUDE]... OLD_REF" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
OLD_REF="${1:?usage: make-latexdiff-full.sh [-f FILE] [-m MODE] [-o OUTNAME] [-p MACROFILE]... [-x EXCLUDE]... OLD_REF}"
SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(git rev-parse --show-toplevel)"
MAINDIR="$(dirname "$MAIN")"; MAINFILE="$(basename "$MAIN")"
[ -f "$REPO/$MAIN" ] || { echo "!! $REPO/$MAIN not found" >&2; exit 1; }
SHORT="$(cd "$REPO" && git rev-parse --short "$OLD_REF")"
OUTNAME="${OUTNAME:-$(date +%Y-%m-%d)-diff-vs-$SHORT}"
SCRATCH="${SCRATCH_DIR:-${TMPDIR:-/tmp}/latexdiff}"
TAG="$(basename "$REPO")-$(printf %s "$REPO" | cksum | cut -d" " -f1)"   # unique per repo path
OLD="$SCRATCH/$TAG-old-$SHORT"
BUILD="$SCRATCH/$TAG-latexdiff-build"
HELPER="$SCRIPTDIR/latexdiff-table-compare.py"
EXPANDER="$SCRIPTDIR/latexdiff-expand-macros.py"
UNWRAP="$SCRIPTDIR/latexdiff-unwrap-adjustbox.py"
LDCOMMON=( --graphics-markup=both --encoding=utf8 --append-mboxsafecmd="num,qty,numrange,qtyrange,SI,fpeval,unit" )

echo ">> OLD_REF=$OLD_REF ($SHORT)  FILE=$MAIN  MODE=$MODE  repo=$REPO  scratch=$SCRATCH"

cleanup () { ( cd "$REPO" && git worktree remove --force "$OLD" 2>/dev/null || true ); }
trap cleanup EXIT

# --- 1. OLD worktree ---------------------------------------------------------
mkdir -p "$SCRATCH"
cleanup
rm -rf "$OLD" "$BUILD"
( cd "$REPO" && git worktree add --detach "$OLD" "$OLD_REF" >/dev/null )

# --- 2. BUILD dir = NEW working tree + OLD-only files ------------------------
RSYNC_EX=( --exclude='.git' --exclude='/data/' ${EXTRA_EX[@]+"${EXTRA_EX[@]}"}
           --exclude='*.aux' --exclude='*.log' --exclude='*.bbl' --exclude='*.bcf' --exclude='*.out'
           --exclude='*.fls' --exclude='*.fdb_latexmk' --exclude='*.synctex.gz' --exclude='*-diff-vs-*' )
rsync -a "${RSYNC_EX[@]}" "$REPO"/ "$BUILD"/
rsync -a --ignore-existing "${RSYNC_EX[@]}" "$OLD"/ "$BUILD"/

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
} > "$BUILD/$MAINDIR/old-params-shim.tex"

# --- 4. flatten both docs -----------------------------------------------------
# latexpand runs in FILE's directory, so the flats live in $BUILD/$MAINDIR and
# compile with the same relative paths (figures, .bib, class files) as FILE.
B="$BUILD/$MAINDIR"
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
inject_shim () { perl -0777 -i -pe 's/(\\begin\{document\})/\\input{old-params-shim}\n$1/ unless /old-params-shim/' "$1"; }
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
  python3 "$EXPANDER" "$B/old-flat.tex" ${OLDP[@]+"${OLDP[@]}"} "$B/old-flat-exp.tex" >&2
  python3 "$EXPANDER" "$B/new-flat.tex" ${NEWP[@]+"${NEWP[@]}"} "$B/new-flat-exp.tex" >&2
  python3 "$UNWRAP" "$B/old-flat-exp.tex" "$B/old-flat-unwrap.tex" >&2
  python3 "$UNWRAP" "$B/new-flat-exp.tex" "$B/new-flat-unwrap.tex" >&2
  strip_rules "$B/old-flat-unwrap.tex" "$B/old-flat-norule.tex"
  strip_rules "$B/new-flat-unwrap.tex" "$B/new-flat-norule.tex"
  ( cd "$B" && latexdiff "${LDCOMMON[@]}" \
        --config="PICTUREENV=(?:picture|DIFnomarkup)[\w\d*@]*" \
        old-flat-norule.tex new-flat-norule.tex > main-diff.tex 2> latexdiff.stderr )
  inject_shim "$B/main-diff.tex"
  fix_multicolumn "$B/main-diff.tex"
  ( cd "$B" && latexmk -pdf -interaction=nonstopmode main-diff.tex > compile.log 2>&1 || true )
  errcount "$B/main-diff.log"
}
build_opaque () {
  ( cd "$B" && latexdiff "${LDCOMMON[@]}" \
        --config="PICTUREENV=(?:picture|DIFnomarkup|tabular|longtable|threeparttable)[\w\d*@]*" \
        old-flat.tex new-flat.tex > main-diff.tex 2> latexdiff.stderr )
  inject_shim "$B/main-diff.tex"
  ( cd "$B" && latexmk -pdf -interaction=nonstopmode main-diff.tex > compile.log 2>&1 || true )
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
cp "$B/table-value-diff.txt" "$REPO/$MAINDIR/$OUTNAME-table-values.txt"
rm -rf "$BUILD"
echo ">> DONE (table mode: $chosen)"
echo "   $REPO/$MAINDIR/$OUTNAME.pdf"
echo "   $REPO/$MAINDIR/$OUTNAME-table-values.txt"

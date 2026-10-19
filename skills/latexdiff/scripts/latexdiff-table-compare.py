#!/usr/bin/env python3
"""Compare tabular contents of two flattened LaTeX docs, keyed by the nearest
preceding \\label. Rename-robust: matches tables by paper identity, not filename.
Emits a self-contained value-change report with inline [-old-]{+new+} word-diffs.
Usage: latexdiff-table-compare.py OLD_FLAT NEW_FLAT REPORT_OUT [OLD_LABEL]
"""
import re, sys, pathlib, difflib

def load_blocks(path):
    txt = pathlib.Path(path).read_text(errors="replace").replace("\r", "")
    labels = [(m.start(), m.group(1)) for m in re.finditer(r"\\label\{([^}]*)\}", txt)]
    blocks, counters = {}, {}
    for m in re.finditer(r"\\begin\{tabular\}.*?\\end\{tabular\}", txt, re.S):
        start = m.start()
        lab = "(no-label)"
        for pos, name in labels:
            if pos < start: lab = name
            else: break
        n = counters.get(lab, 0); counters[lab] = n + 1
        key = lab if n == 0 else f"{lab}#{n+1}"
        body = re.sub(r"(?<!\\)%.*", "", m.group(0))           # strip comments
        rows = re.split(r"\\\\", body)                          # split on \\
        norm = [re.sub(r"\s+", " ", r).strip() for r in rows if r.strip()]
        blocks[key] = norm
    return blocks

def word_diff(old_row, new_row):
    o, n = old_row.split(" "), new_row.split(" ")
    sm = difflib.SequenceMatcher(a=o, b=n, autojunk=False)
    out = []
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal":   out.append(" ".join(o[i1:i2]))
        elif tag == "delete":out.append("[-" + " ".join(o[i1:i2]) + "-]")
        elif tag == "insert":out.append("{+" + " ".join(n[j1:j2]) + "+}")
        elif tag == "replace":
            out.append("[-" + " ".join(o[i1:i2]) + "-]{+" + " ".join(n[j1:j2]) + "+}")
    return " ".join(x for x in out if x)

old, new = load_blocks(sys.argv[1]), load_blocks(sys.argv[2])
keys = sorted(set(old) | set(new))
same   = [k for k in keys if k in old and k in new and old[k] == new[k]]
chg    = [k for k in keys if k in old and k in new and old[k] != new[k]]
onlyo  = [k for k in keys if k in old and k not in new]
onlyn  = [k for k in keys if k in new and k not in old]

L = []
L.append("TABLE VALUE-CHANGE REPORT")
OLDLAB = sys.argv[4] if len(sys.argv) > 4 else "OLD"
L.append(f"OLD = {OLDLAB}   vs   NEW = current working tree")
L.append("Method: latexpand-flattened both docs; all tabular blocks matched by nearest \\label")
L.append("        (rename-robust); whitespace/comments normalized; row-level word-diff.")
L.append("[-...-] = OLD value    {+...+} = NEW value")
L.append("=" * 80)
L.append(f"SUMMARY: {len(keys)} tables matched | {len(same)} identical | {len(chg)} changed "
         f"| {len(onlyn)} added | {len(onlyo)} dropped")
L.append("=" * 80)
L.append("\nIDENTICAL (no value change):")
for k in same:  L.append(f"   = {k}")
if onlyo:
    L.append("\nOLD-ONLY (table dropped/renamed away):")
    for k in onlyo: L.append(f"   - {k}")
if onlyn:
    L.append("\nNEW-ONLY (table added):")
    for k in onlyn: L.append(f"   + {k}")
L.append("\n" + "=" * 80)
L.append("CHANGED TABLES (row-by-row value diffs)")
L.append("=" * 80)
for k in chg:
    L.append("\n" + "#" * 80)
    L.append(f"## {k}")
    L.append("#" * 80)
    o, n = old[k], new[k]
    sm = difflib.SequenceMatcher(a=o, b=n, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal":
            continue
        if tag == "replace":
            for a, b in zip(o[i1:i2], n[j1:j2]):
                if a != b: L.append("  " + word_diff(a, b))
            extra_o, extra_n = o[i1+ (j2-j1):i2], n[j1+(i2-i1):j2]
            for a in extra_o: L.append("  [-" + a + "-]")
            for b in extra_n: L.append("  {+" + b + "+}")
        elif tag == "delete":
            for a in o[i1:i2]: L.append("  [-" + a + "-]")
        elif tag == "insert":
            for b in n[j1:j2]: L.append("  {+" + b + "+}")

pathlib.Path(sys.argv[3]).write_text("\n".join(L) + "\n")
print(f"wrote {sys.argv[3]}: {len(L)} lines")
print(f"SUMMARY: {len(keys)} matched | {len(same)} identical | {len(chg)} changed | {len(onlyn)} added | {len(onlyo)} dropped")

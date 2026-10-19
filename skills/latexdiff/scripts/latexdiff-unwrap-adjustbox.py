#!/usr/bin/env python3
"""Replace the COMMAND form \\adjustbox{opts}{BODY} with BODY in a flattened doc.

latexdiff does not mark changes inside a command argument; a table wrapped in
\\adjustbox{max totalsize=...}{% ... } falls back to a
block-level diff (old commented out, new shown unmarked). Unwrapping in the diffed
copies lets latexdiff mark cells. Tables may overflow the page in the diff PDF;
the committed sources are untouched. The environment form \\begin{adjustbox} is fine
and is left alone.

Usage: latexdiff-unwrap-adjustbox.py IN OUT
"""
import sys, pathlib

txt = pathlib.Path(sys.argv[1]).read_text(errors="replace")

def match_brace(s, i):
    """s[i] == '{'; return index of matching '}' (ignores escaped braces and % comments)."""
    depth = 0
    j = i
    while j < len(s):
        c = s[j]
        if c == '\\':
            j += 2
            continue
        if c == '%':
            j = s.find('\n', j)
            if j == -1:
                return -1
            continue
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return j
        j += 1
    return -1

out, pos, n = [], 0, 0
key = '\\adjustbox{'
while True:
    k = txt.find(key, pos)
    if k == -1:
        out.append(txt[pos:]); break
    # skip if this line is a comment
    line_start = txt.rfind('\n', 0, k) + 1
    if txt[line_start:k].lstrip().startswith('%'):
        out.append(txt[pos:k + len(key)]); pos = k + len(key); continue
    o1 = k + len(key) - 1
    c1 = match_brace(txt, o1)
    o2 = c1 + 1
    while o2 < len(txt) and txt[o2] in ' \t':
        o2 += 1
    if c1 == -1 or o2 >= len(txt) or txt[o2] != '{':
        out.append(txt[pos:k + len(key)]); pos = k + len(key); continue
    c2 = match_brace(txt, o2)
    if c2 == -1:
        out.append(txt[pos:]); break
    out.append(txt[pos:k])
    out.append(txt[o2 + 1:c2])
    pos = c2 + 1
    n += 1

pathlib.Path(sys.argv[2]).write_text(''.join(out))
print(f"{pathlib.Path(sys.argv[2]).name}: unwrapped {n} \\adjustbox commands")

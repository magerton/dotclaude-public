#!/usr/bin/env python3
"""Expand parameter macros to their literal values in a flattened LaTeX doc.

latexdiff compares LaTeX *source*, so a macro whose VALUE changed but whose NAME
stayed the same (e.g. a regenerated \\newcommand in a parameters file written by Stata)
is invisible to it. Expanding every parameter macro to its literal value BEFORE the
diff turns such a change into a literal text change latexdiff will mark.

Only definitions whose value is a plain literal (no backslash or braces) are
expanded. Derived macros, e.g. ones defined with nested \\fpeval{...}, are left
as macros, so a value change in a derived macro is NOT surfaced unless its inputs
appear directly in the text.

Replacement rules:
  - only whole control words (maximal [A-Za-z]+) are replaced, so \\Coef never
    corrupts \\CoefFoo;
  - only the BODY (after \\begin{document}) is touched, so definitions in the
    preamble are left intact;
  - expand to the value as-is (raw, full precision) -- if the use site wraps it in
    \\num[round-mode=...]{} the rounding still applies at compile time.

Use the OLD parameter files for the OLD flattened doc and the NEW ones for the NEW
doc, so each side carries its own values.

Usage: latexdiff-expand-macros.py FLAT_IN PARAM1.tex [PARAM2.tex ...] OUT
"""
import re, sys, pathlib

flat_in = sys.argv[1]
out     = sys.argv[-1]
pfiles  = sys.argv[2:-1]

d = {}
for pf in pfiles:
    try:
        t = pathlib.Path(pf).read_text(errors="replace").replace("\r", "")
    except FileNotFoundError:
        continue
    for m in re.finditer(r"\\newcommand\{\\([A-Za-z]+)\}\{([^{}\\]*)\}", t):
        d[m.group(1)] = m.group(2)

txt = pathlib.Path(flat_in).read_text(errors="replace")
i = txt.find(r"\begin{document}")
pre, body = (txt[:i], txt[i:]) if i != -1 else ("", txt)

n = [0]
def repl(m):
    if m.group(1) in d:
        n[0] += 1
        # consume an empty {} terminator (\Foo{}) along with the macro
        return d[m.group(1)]
    return m.group(0)

body = re.sub(r"\\([A-Za-z]+)(?:\{\})?", repl, body)
pathlib.Path(out).write_text(pre + body)
print(f"{pathlib.Path(out).name}: {len(d)} param defs available, {n[0]} macro uses expanded in body")

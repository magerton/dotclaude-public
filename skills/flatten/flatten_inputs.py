#!/usr/bin/env python3
r"""Recursively inline \input{...}/\include{...} files, newline-safely.

latexpand expands \input mid-line, so a file ending in `%` comments out
whatever the parent line inlines next (this silently deleted a paragraph of
the paper in a refine.ink submission). This inliner always emits inlined file
content starting on a fresh line and terminates it with a newline, so a
trailing `%` in one file can never swallow the next \input on the same
parent line. Comments are left untouched (\input inside a comment is not
expanded); run latexpand afterwards to strip comments and embed the .bbl.

Usage: python3 flatten_inputs.py main.tex > flattened.tex
"""
import re
import sys
from pathlib import Path

INPUT_RE = re.compile(r"\\(?:input|include)\{([^}]+)\}")


def split_comment(line: str):
    """Split a line into (code, comment) at the first unescaped %."""
    for m in re.finditer(r"%", line):
        i = m.start()
        if i == 0 or line[i - 1] != "\\":
            return line[:i], line[i:]
    return line, ""


def inline(path: Path, root: Path, out, seen):
    if path in seen:
        raise RuntimeError(f"circular \\input: {path}")
    seen = seen | {path}
    for line in path.read_text().splitlines():
        code, comment = split_comment(line)
        pos = 0
        for m in INPUT_RE.finditer(code):
            out.write(code[pos:m.start()])
            target = root / m.group(1)
            if target.suffix != ".tex":
                target = target.with_suffix(".tex")
            out.write("\n")  # never inline mid-line
            inline(target, root, out, seen)
            out.write("\n")
            pos = m.end()
        out.write(code[pos:] + comment + "\n")


def main():
    main_tex = Path(sys.argv[1])
    inline(main_tex, main_tex.parent, sys.stdout, frozenset())


if __name__ == "__main__":
    main()

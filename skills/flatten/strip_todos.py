#!/usr/bin/env python3
"""Strip \\todo[...]{...} commands (brace-aware) from a LaTeX file.

Usage: strip_todos.py input.tex > output.tex

Handles optional [..] arguments and nested braces inside the mandatory
argument. Leaves \\usepackage{todonotes} alone (harmless), and does not
touch coauthor notes written as \\textbf{...} -- only \\todo commands.
"""
import re
import sys


def strip_todos(text: str) -> str:
    out = []
    i = 0
    n = len(text)
    pat = re.compile(r"\\todo\b")
    while i < n:
        m = pat.search(text, i)
        if not m:
            out.append(text[i:])
            break
        out.append(text[i:m.start()])
        j = m.end()
        # optional [...] argument
        if j < n and text[j] == "[":
            depth = 1
            j += 1
            while j < n and depth:
                if text[j] == "[":
                    depth += 1
                elif text[j] == "]":
                    depth -= 1
                j += 1
        # mandatory {...} argument with nested braces
        if j < n and text[j] == "{":
            depth = 1
            j += 1
            while j < n and depth:
                if text[j] == "\\" and j + 1 < n:
                    j += 2  # skip escaped char, e.g. \{ or \}
                    continue
                if text[j] == "{":
                    depth += 1
                elif text[j] == "}":
                    depth -= 1
                j += 1
        i = j
    return "".join(out)


if __name__ == "__main__":
    src = open(sys.argv[1]).read() if len(sys.argv) > 1 else sys.stdin.read()
    sys.stdout.write(strip_todos(src))

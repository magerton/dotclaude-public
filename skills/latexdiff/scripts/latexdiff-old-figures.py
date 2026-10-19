#!/usr/bin/env python3
"""Point \\includegraphics at old-only figures fetched from git, so a diff PDF can show
figures that exist at OLD_REF but not in the working tree, without checking out OLD_REF.

For each \\includegraphics{name} in DIFF_TEX: if the file resolves from MAINDIR in the
working tree (trying the document's \\graphicspath folders and the usual extensions),
leave it alone. Otherwise look for the same candidates at OLD_REF; if one exists, write
it with `git show` under OUTDIR and replace the name with that absolute path.

Usage: latexdiff-old-figures.py DIFF_TEX REPO MAINDIR OLD_REF OUTDIR
Prints one line per fetched figure.
"""
import os, re, subprocess, sys

diff_tex, repo, maindir, ref, outdir = sys.argv[1:6]
EXTS = ["", ".pdf", ".png", ".jpg", ".jpeg", ".eps"]
txt = open(diff_tex, errors="replace").read()

gp = re.search(r"\\graphicspath\s*\{((?:\s*\{[^{}]*\})+)\s*\}", txt)
prefixes = [""] + (re.findall(r"\{([^{}]*)\}", gp.group(1)) if gp else [])


def candidates(name):
    for pre in prefixes:
        for ext in EXTS:
            yield os.path.normpath(os.path.join(maindir, pre + name + ext))


def in_tree(rel):
    return os.path.isfile(os.path.join(repo, rel))


def at_ref(rel):
    if rel.startswith(".."):  # outside the repo
        return False
    r = subprocess.run(["git", "-C", repo, "cat-file", "-e", f"{ref}:{rel}"], capture_output=True)
    return r.returncode == 0


cache = {}


def resolve(name):
    if name in cache:
        return cache[name]
    cache[name] = None
    if any(in_tree(c) for c in candidates(name)):
        return None
    for c in candidates(name):
        if at_ref(c):
            dest = os.path.join(outdir, c)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with open(dest, "wb") as f:
                subprocess.run(["git", "-C", repo, "show", f"{ref}:{c}"], stdout=f, check=True)
            print(f"   old-only figure: {c}")
            cache[name] = os.path.abspath(dest)
            break
    return cache[name]


def sub(m):
    new = resolve(m.group(2).strip())
    return m.group(0) if new is None else f"{m.group(1)}{{{new}}}"


out = re.sub(r"(\\includegraphics\*?\s*(?:\[[^\]]*\])?\s*)\{([^{}]+)\}", sub, txt)
if out != txt:
    open(diff_tex, "w").write(out)

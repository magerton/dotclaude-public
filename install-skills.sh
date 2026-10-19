#!/usr/bin/env bash
# Link this repo's Claude Code skills into ~/.claude/skills (or $CLAUDE_HOME/skills).
#   ./install-skills.sh               all skills
#   ./install-skills.sh checkin zotero  only these
# Changes nothing else in ~/.claude. Safe to re-run. An existing skill of the same name that is not
# already the right link is moved to ~/.claude/skills-backup/<name>-YYYYMMDD-HHMMSS (outside skills/,
# so Claude Code does not load it twice), never deleted. To remove a skill,
# delete its link: rm ~/.claude/skills/<name>
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd -P)"   # physical path, so links survive a symlinked checkout
DEST="${CLAUDE_HOME:-$HOME/.claude}/skills"
BACKUP="${CLAUDE_HOME:-$HOME/.claude}/skills-backup"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DEST"
if [ "$#" -gt 0 ]; then names=("$@"); else names=(); for d in "$REPO"/skills/*/; do names+=("$(basename "$d")"); done; fi
status=0
for name in "${names[@]}"; do
  name="${name%/}"
  case "$name" in ""|.*|*/*) echo "invalid skill name: '$name'" >&2; status=1; continue ;; esac
  src="$REPO/skills/$name"; dst="$DEST/$name"
  [ -f "$src/SKILL.md" ] || { echo "no such skill: $name" >&2; status=1; continue; }
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then echo "ok       $dst"; continue; fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then mkdir -p "$BACKUP"; mv "$dst" "$BACKUP/$name-$STAMP"; echo "backup   $dst -> $BACKUP/$name-$STAMP"; fi
  ln -s "$src" "$dst"; echo "linked   $dst -> $src"
done
exit $status

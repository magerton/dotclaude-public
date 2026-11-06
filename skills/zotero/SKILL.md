---
name: zotero
description: Look up references in the user's Zotero library — whether an item exists, its cite key, metadata, abstract, or notes. For a passage from a paper's full text, use fetch-zotero-pdf instead.
argument-hint: "<search terms or cite key>"
---

# Zotero lookups

If the repo has `.claude/skills/zotero/SKILL.md`, read it for project notes (bib file, known duplicates).

**Start Zotero first.** Run this before the first Zotero call. It starts Zotero in the background if it is not running, waits 2 seconds, then pings the local API for up to 45 seconds. Keep the wait: a ping sent straight after launch may stop the library loading, and the API then hangs. `open` is macOS; on Linux, start `zotero &` instead. Run it exactly as written: permission allow rules match this text.

```bash
pgrep -qx zotero || open -g -a Zotero && sleep 2 && curl -sf -o /dev/null -m 5 --retry 40 --retry-delay 1 --retry-connrefused --retry-max-time 40 http://127.0.0.1:23119/api/
```

If the command fails, Zotero did not start, is not responding, or its local API is off (Settings > Advanced > "Allow other applications on this computer to communicate with Zotero"). Tell the user and stop.

**Search** (`limit` ≤ 10; each result costs context):
- Author / title / year: `zotero_search_items(query="kitagawa tetenov", qmode="titleCreatorYear", limit=5)`
- Cite key: `zotero_search_items(query="kitagawa2018who")`
- Words anywhere, incl. abstracts and notes: `qmode="everything"`
- `zotero_search_items` and `zotero_advanced_search` are keyword searches. Semantic search (`zotero_semantic_search`) returns verbose results and may be denied by your permissions; use keyword search first.

**Details**:
- Metadata or BibTeX: `zotero_get_item_metadata(item_key="<item key>", format="bibtex")`
- Abstract: `zotero_get_item_metadata(item_key=..., include_abstract=true)`
- Attachments and notes: `zotero_get_item_children`, `zotero_get_notes`, `zotero_get_annotations`

**Full text**: never call `zotero_get_item_fulltext` in the main conversation (30–50k tokens). Use `/fetch-zotero-pdf <key> — <what you need>`, which runs in its own context and returns only the passage.

**Conventions**:
- Cite keys: `[author][year][firstword]`, e.g. `bhattacharya2012inferring`. A project's .bib is the user's Better BibTeX export; keys there match Zotero.
- Agents cannot add items to Zotero or trigger a bib export. If a reference is missing, give the user author, year, title, and venue, and ask the user to add it.

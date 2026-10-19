---
name: zotero
description: Look up references in the user's Zotero library — whether an item exists, its cite key, metadata, abstract, or notes. For a passage from a paper's full text, use fetch-zotero-pdf instead.
argument-hint: "<search terms or cite key>"
---

# Zotero lookups

If the repo has `.claude/skills/zotero/SKILL.md`, read it for project notes (bib file, known duplicates).

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

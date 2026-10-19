---
name: fix-latex-citations
description: Parse LaTeX compile output for missing citations, search Zotero for each, and generate an action report.
argument-hint: "[log-file-or-tex-file]"
---

# Fix Missing LaTeX Citations

Parse LaTeX compilation output for undefined citation warnings, search Zotero for each missing cite key, and produce an actionable report.

## Input

Accepts optional argument:
- A `.log` file path to parse
- A `.tex` file path (will look for corresponding `.log`)
- If no argument, searches for most recent `.log` in project

## Workflow

1. **Parse log file** for undefined citation warnings:
   - Pattern: `LaTeX Warning: Citation .* on page .* undefined`
   - Pattern: `Package natbib Warning: Citation .* undefined`
   - Pattern: `Package biblatex Warning: Citation .* undefined`
   - Extract cite keys

2. **Search Zotero** for each missing cite key using `zotero_search_items`. Try searches in this order, stopping when a match is found:

   **Step 1: Search for exact cite key** (most specific)
   - Query: the full cite key (e.g., `zavala-araiza2015toward`)

   **Step 2: Search for key without hyphens/punctuation**
   - Query: `zavala araiza 2015 toward`

   **Step 3: Search for author + year**
   - Extract author name and year from key (e.g., `zavala-araiza 2015`)
   - This catches cases where title words differ

   **Step 4: Search for author + title keywords**
   - If the key contains descriptive words (e.g., `superemitters`), search for author + those keywords
   - Query: `zavala-araiza superemitters`

   Only after exhausting these should you report "Not found in Zotero"

3. **Get BibTeX for matches**: When found, use `zotero_get_item_metadata` with `format: bibtex` to get the actual cite key Zotero uses.

4. **Generate report** with actionable fixes:

   **Found in Zotero (key mismatch)** - item exists but with different cite key:
   ```
   - Missing: `zavala-araiza2015toward`
   - Found: `zavala2015toward` - "Toward a Functional Definition..." (ES&T 2015)
   - Fix Option A (recommended): Change citation in .tex to `zavala2015toward`
   - Fix Option B (not recommended): Add entry to .bib with expected key (provide BibTeX)
   ```

   **Found in Zotero (not in .bib)** - item exists, just needs export:
   ```
   - cite_key: [title] by [author] ([year])
     Action: Add to project collection, re-export .bib
   ```

   **Not in Zotero** (need to import):
   ```
   - cite_key: [search suggestion]
     Action: Search Google Scholar: [link]
   ```

## Context Cost Warning

**Multiple Zotero searches consume significant context.** If many citations are missing, each search adds metadata to context. For >3-4 missing citations:
- **Use a subagent** via Task tool to isolate Zotero queries
- **Set `limit=3`** on each search to reduce verbosity
- **Stop early** once a match is found (don't run all 4 search variants)

## Notes

- Cite key format with Better BibTeX's common setting: `[author][year][firstword]` (e.g., `smith2023economics`)
- **Common issue**: Zotero/Better BibTeX may have slightly different cite keys (e.g., `zavala2015toward` vs `zavala-araiza2015toward`). Always check if the paper has a variant key.
- After adding items to collection, user must re-export Better BibTeX .bib file
- Use subagent for Zotero searches to manage context

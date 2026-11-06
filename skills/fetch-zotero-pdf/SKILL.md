---
name: fetch-zotero-pdf
description: Read the full text of a paper in Zotero and return only the passage needed (a theorem, lemma, definition, assumption, or quote). Runs in a separate context so the full text never enters the main conversation. Pass a cite key or search terms plus what you need from the paper.
context: fork
agent: general-purpose
background: false
argument-hint: "<cite-key or search terms> — <what you need>"
---

You are retrieving one specific piece of content from a paper for an economics researcher writing a paper.

Request: $ARGUMENTS

First, start Zotero. This command starts it in the background if it is not running, waits 2 seconds, then pings the local API for up to 45 seconds. Keep the wait: a ping sent straight after launch may stop the library loading, and the API then hangs. `open` is macOS; on Linux, start `zotero &` instead. Run it exactly as written: permission allow rules match this text.

```bash
pgrep -qx zotero || open -g -a Zotero && sleep 2 && curl -sf -o /dev/null -m 5 --retry 40 --retry-delay 1 --retry-connrefused --retry-max-time 40 http://127.0.0.1:23119/api/
```

If the command fails, Zotero did not start, is not responding, or its local API is off (Settings > Advanced > "Allow other applications on this computer to communicate with Zotero"). Say so, then go to the `~/Zotero/storage` fallback in step 2 if you can identify the attachment; otherwise stop.

1. Find the item with `zotero_search_items` (cite keys look like `vaart1998asymptotic`; use `limit` ≤ 5). If several items match and the request does not settle it, pick the closest and say which you picked. Book chapters can be separate Zotero items or child attachments (`zotero_get_item_children`).
2. Get the text with `zotero_get_item_fulltext`. If that fails, find the PDF under `~/Zotero/storage/<attachment key>/` and read the relevant pages.
3. Return only what was asked: the exact statement (theorem/lemma number, page, hypotheses in full, verbatim where it matters for a proof), plus one or two sentences of context if needed. Include title, authors, year, cite key, and page numbers. Say plainly if the paper does not contain what was asked.

Do not return the full text or a general summary.

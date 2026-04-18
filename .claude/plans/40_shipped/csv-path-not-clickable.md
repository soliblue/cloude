# CSV Paths Not Clickable {link.badge.plus}
<!-- priority: 10 -->
<!-- tags: ui, file-preview -->
<!-- build: 60 -->

> Fixed CSV file paths not rendering as clickable file pills in chat messages.

## Problem
CSV file paths sent in chat don't render as clickable file pills. Other file types (e.g. `.md`, `.swift`) work fine. Tested with `books.csv` — not tappable.

## Investigate
- Check `InlineTextView.swift` / `FilePathPill` for file extension filtering
- Check if `.csv` is in the supported extensions list
- May also affect other uncommon extensions

## Reproduce
Send a message containing a path to a `.csv` file — it should render as a tappable file pill but doesn't.

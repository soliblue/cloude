# CSV Paths Not Clickable
<!-- build: 60 -->

<!-- priority: 2 -->
<!-- tags: bug, ui, files -->

## Problem
CSV file paths sent in chat don't render as clickable file pills. Other file types (e.g. `.md`, `.swift`) work fine. Tested with `/Users/soli/Desktop/CODING/cloude/books.csv` — not tappable.

## Investigate
- Check `InlineTextView.swift` / `FilePathPill` for file extension filtering
- Check if `.csv` is in the supported extensions list
- May also affect other uncommon extensions

## Reproduce
Send a message containing a path to a `.csv` file — it should render as a tappable file pill but doesn't.

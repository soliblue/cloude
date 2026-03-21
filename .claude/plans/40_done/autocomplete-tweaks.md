# Autocomplete tweaks {text.cursor}
<!-- priority: 10 -->
<!-- tags: input -->
<!-- build: 56 -->

> Increased autocomplete trigger length to 90 chars and prevented ghost text from expanding the input bar.

## Changes
- Max input length for autocomplete trigger: 30 → 90 characters
- Ghost text overlay no longer expands the input bar — uses `fixedSize(horizontal: false, vertical: false)` to stay within the TextField's bounds, truncates with `...` if too long
- Debounce was already 500ms (no change needed)

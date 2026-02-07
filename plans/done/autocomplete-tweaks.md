# Autocomplete tweaks

## Changes
- Max input length for autocomplete trigger: 30 → 90 characters
- Ghost text overlay no longer expands the input bar — uses `fixedSize(horizontal: false, vertical: false)` to stay within the TextField's bounds, truncates with `...` if too long
- Debounce was already 500ms (no change needed)

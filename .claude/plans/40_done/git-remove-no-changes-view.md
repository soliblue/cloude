# Remove "No Changes" Empty State from Git View

Removed the ContentUnavailableView("No Changes") from GitChangesView. The branch header already shows 0 file count, which is sufficient.

## Test
- Open git tab with a clean working tree
- Should show empty list, no "No Changes" placeholder
- Header still shows branch name + 0 count

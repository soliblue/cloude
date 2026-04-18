# Remove "No Changes" Empty State from Git View {xmark.circle}
<!-- priority: 10 -->
<!-- tags: ui, git -->

> Removed redundant "No Changes" placeholder from git view since header already shows 0 count.

Removed the ContentUnavailableView("No Changes") from GitChangesView. The branch header already shows 0 file count, which is sufficient.

## Test
- Open git tab with a clean working tree
- Should show empty list, no "No Changes" placeholder
- Header still shows branch name + 0 count

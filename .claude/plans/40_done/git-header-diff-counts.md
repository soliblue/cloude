# Git Tab Header: Inline Diff Counts {plusminus}
<!-- build: 120 -->
<!-- priority: 6 -->
<!-- tags: git, ui -->

> Git icon in the window header should show +N -N when there are changes.

## Problem
The window header always shows a plain git icon for the git tab, even when there are staged or unstaged changes. The diff counts are only visible after tapping into the git tab itself.

## Desired Outcome
When there are changes, replace the git icon in the window header with the `+N -N` diff counts using the same visual style as the counts shown inside the git tab. When there are no changes, show the regular git icon as before.

## How to Test
1. Open a conversation with a working directory that has git changes
2. Look at the window header tab bar — the git tab should show `+N -N` instead of the icon
3. If there are no changes, it should show the regular git icon
4. The counts should update as files change

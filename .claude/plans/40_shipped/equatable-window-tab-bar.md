# Equatable WindowTabBar {gauge.with.dots.needle.bottom.50percent}
<!-- priority: 10 -->
<!-- tags: ui, performance -->
> Make WindowTabBar equatable, reducing renders from 22 to 2 per stream.

## Changes

- Added Equatable conformance to WindowTabBar comparing display properties only
- Added .equatable() modifier at the call site in MainChatView+Windows
- Side effect: ConvView renders also reduced from 21 to 11

## Verify

Outcome: tab bar displays correctly with cost, folder name, and git stats. Tab switching between chat/files/git works. Git additions/deletions update when git status changes.

Test: open a conversation, verify the tab bar shows cost, folder name, and git branch/stats. Switch between chat, files, and git tabs. Make a file change and verify git stats update. Check debug overlay for WindowTabBar render count (should be ~2 per stream).

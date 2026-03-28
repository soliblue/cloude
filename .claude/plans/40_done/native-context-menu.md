# Native Context Menu for Messages
<!-- build: 110 -->

Replaced the custom long-press overlay (glass morphism horizontal menu with manual positioning) with native iOS `.contextMenu`. Actions: Copy, Select Text, Collapse/Expand.

## Test
- [ ] Long-press a user message: Copy and Select Text appear
- [ ] Long-press an assistant message: Copy, Select Text, and Collapse appear
- [ ] Long-press a collapsed message: shows Expand instead of Collapse
- [ ] Copy works and shows toast
- [ ] Select Text opens the text selection sheet
- [ ] Collapse/Expand toggles correctly
- [ ] Long-press on live (streaming) messages does nothing
- [ ] Messages with interactive widgets have no context menu conflict

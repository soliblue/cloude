# Suggestions Float as Overlay
<!-- build: 115 -->

Suggestion pills (slash commands, file suggestions, history) now float above the input bar as an overlay instead of being in a VStack that pushes the message list up.

## Test
- [ ] Type `/` and verify suggestions appear above input bar without shifting messages
- [ ] Type `@` with a file query and verify file suggestions float correctly
- [ ] Tap a suggestion pill and verify it works (hit testing)
- [ ] Horizontal scroll through suggestions works
- [ ] Suggestions have a visible backdrop (not transparent between pills)
- [ ] Dismiss suggestions and verify no layout artifacts

# Screenshot Command
<!-- priority: 10 -->
<!-- build: 56 -->

Add `cloude screenshot` command that captures the iOS screen and sends it back to the conversation as an image.

## Flow
1. CLI outputs `[[cloude:screenshot:]]` marker
2. Mac agent broadcasts `.screenshot(conversationId:)` to iOS
3. iOS captures its own view hierarchy
4. iOS sends the image back as a chat message with image attachment
5. Claude receives the screenshot as visual context

## Files
- `ServerMessage.swift` — add `.screenshot` case
- `AppDelegate+CommandParsing.swift` — handle `screenshot` action
- `ConnectionManager+API.swift` — receive screenshot command, capture view, send back
- `CLAUDE.md` — document the command
- `FEATURES.md` — add to feature list

## Notes
- Captures Cloude's own UI only (iOS doesn't allow full-screen capture without ReplayKit)
- Follows the `cloude ask` pattern: request → iOS acts → sends response as chat message
- No user interaction needed — capture is automatic

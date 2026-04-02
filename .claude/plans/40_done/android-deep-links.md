# Android Deep Links {link}
<!-- priority: 10 -->
<!-- tags: android, architecture, deep-links -->

> Implement `cloude://` URL scheme for remote app control from Claude Code tool calls.

## Context

iOS has a comprehensive deep link system that lets Claude Code (via tool calls) control the app remotely. This enables features like opening specific files, navigating to git diffs, switching conversations, and triggering device actions -- all from within a Claude Code session.

## Scope

Implement an intent/URI handler for the `cloude://` scheme supporting:

- `cloude://file?path=...` - open file in preview
- `cloude://browser?path=...` - open file browser at directory
- `cloude://diff?path=...` - open git diff for file
- `cloude://send?text=...` - inject text into input and optionally send
- `cloude://usage` - open usage stats sheet
- `cloude://search?q=...` - search conversations
- `cloude://conversation/new`, `/duplicate`, `/refresh` - conversation management
- `cloude://model?name=...` / `cloude://effort?level=...` - set model/effort
- `cloude://window/create`, `/close`, `/select` - window management
- `cloude://settings`, `/memories`, `/plans`, `/whiteboard` - open sheets
- `cloude://screenshot` - capture and return screen
- `cloude://haptic?intensity=...` - trigger vibration

## Implementation

- Register intent filter in AndroidManifest
- Dispatch handler in main Activity or a dedicated DeepLinkRouter
- Each deep link maps to existing UI actions or ViewModel methods
- WebSocket messages from agent can carry deep link URIs to trigger actions

## Dependencies

None -- uses existing UI components. Screenshot and haptic are separate tickets.

## Implementation Status

### Done
- AndroidManifest.xml: intent filter for `cloude://` scheme with VIEW action and BROWSABLE category
- DeepLinkRouter.kt: routes URIs to app actions (file, files, git, send, usage, search, conversation, window, tab, run, environment, settings, memories, plans, deploy)
- MainActivity: deepLinkRouter initialized with UIActions, handles intent in onCreate and onNewIntent
- Build compiles successfully

### Files changed
- android/.../AndroidManifest.xml (intent filter added)
- android/.../App/DeepLinkRouter.kt (new)
- android/.../App/MainActivity.kt (router init, onNewIntent)

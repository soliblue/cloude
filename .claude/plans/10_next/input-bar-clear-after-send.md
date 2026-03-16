# Input Bar Text Not Clearing After Send

After sending a message, the input text sometimes stays visible (even overlapping with the placeholder) until the user taps somewhere else or taps the field again.

## Assumptions

- The placeholder is a manual ZStack overlay in `GlobalInputBar.swift` (line 312-317) that checks `inputText.isEmpty`
- `inputText = ""` in `sendMessage()` (line 46) fires synchronously right after the send
- SwiftUI TextField has an internal UIKit text storage that can get momentarily out of sync with the `@Binding`
- When the binding clears but UIKit hasn't flushed, both old text and placeholder render simultaneously
- Tapping the field forces a UIKit sync, which is why interaction fixes it

## Proposed Fix

Wrap `inputText = ""` in `DispatchQueue.main.async` so it fires in the next run loop tick, after the TextField's UIKit layer has settled from the send action. Keep images/files/drafts clearing synchronously (no UIKit backing issue).

**Files:** `MainChatView+Messaging.swift`

# Input Autocomplete (Haiku Ghost Text)
<!-- priority: 10 -->
<!-- tags: input, ui -->
<!-- build: 56 -->

## Summary
Add inline autocomplete suggestions to the input bar. As the user types, Haiku generates a completion that appears as ghost text (dimmed) after the cursor. Swiping right on the input bar accepts the suggestion.

## Architecture

### Flow
1. User types in input bar → debounce 500ms
2. iOS sends `autocomplete` request to Mac agent with: input text + last few messages for context
3. Mac agent calls Haiku API directly (no CLI) with a tight prompt
4. Mac agent sends `autocomplete_result` back to iOS
5. iOS renders the suggestion as ghost text after the real input
6. User swipes right → suggestion fills the input
7. Any keystroke → clears current suggestion, triggers new debounce

### Why CLI with Haiku?
- Use the existing ClaudeCodeRunner infrastructure — spawn a quick CLI call with `--model haiku`
- No separate API key management or direct HTTP calls needed
- The CLI handles auth, rate limiting, and everything else
- Keep it simple: same pattern as chat, just a lightweight one-shot prompt

## Implementation

### 1. Shared Protocol (CloudeShared)

**ClientMessage** — add:
```swift
case autocomplete(text: String, context: [String], workingDirectory: String?)
```
- `text`: current input text
- `context`: last 4 messages (alternating user/assistant) for relevance
- `workingDirectory`: for project-aware suggestions

**ServerMessage** — add:
```swift
case autocompleteResult(text: String, requestText: String)
```
- `text`: the suggested completion (just the part after what user typed)
- `requestText`: echo back what was requested, so stale results can be discarded

### 2. Mac Agent — AutocompleteService

New file: `Cloude Agent/Services/AutocompleteService.swift`

- Spawns Claude CLI with `--model haiku` and a one-shot prompt
- Uses `--print` flag (or equivalent) for non-interactive output
- System prompt: "Complete the user's message naturally. Output ONLY the completion text, nothing else. Keep it concise."
- Sends the conversation context + partial input
- Returns just the completion suffix
- Kills the process after timeout (3 seconds)

### 3. Mac Agent — Message Handling

In `AppDelegate+MessageHandling.swift`, add case for `.autocomplete`:
- Call `AutocompleteService.complete(...)`
- Send back `.autocompleteResult(...)` on the same connection

### 4. iOS — ConnectionManager

**ConnectionManager+API.swift**:
- Add `requestAutocomplete(text:context:workingDirectory:)` method
- Add `onAutocompleteResult` callback
- Handle `.autocompleteResult` in `handleMessage`

### 5. iOS — GlobalInputBar

**State**:
- `@State var autocompleteSuggestion: String = ""` (the ghost text)
- `@State var autocompleteDebounce: Task<Void, Never>?`

**New callback**:
- `onAutocomplete: ((String, [String], String?) -> Void)?` — triggers request

**Ghost text rendering** (in the ZStack with the TextField):
- After the TextField, overlay a Text view showing `inputText + suggestion` in dimmed color
- Only the suggestion part is visible (the inputText part is transparent/hidden since the real TextField covers it)

**Swipe right to accept**:
- Modify existing gesture: swipe left clears text, swipe RIGHT accepts suggestion
- Currently right-to-left swipe clears. We add left-to-right swipe to accept.
- When accepted: `inputText += autocompleteSuggestion; autocompleteSuggestion = ""`

**Debounce logic** (in `onChange(of: inputText)`):
- Cancel previous debounce task
- Clear current suggestion immediately on any keystroke
- After 500ms of no typing, if text is non-empty and not a slash command, fire `onAutocomplete`

### 6. iOS — MainChatView

Wire up the new callback:
- Pass `onAutocomplete` to GlobalInputBar
- Gather last 4 messages from current conversation as context
- Call `connection.requestAutocomplete(...)`
- Set up `connection.onAutocompleteResult` to update the suggestion state

## UX Details

- Ghost text color: `.secondary.opacity(0.4)` — clearly different from real input
- Ghost text appears inline, same font as input, right after the cursor position
- Minimum input length to trigger: 3 characters (avoid noise on very short input)
- Maximum input length to trigger: 30 characters (user knows what they're typing past that)
- Don't trigger during slash commands (`/`) or `@` mentions
- Don't trigger when conversation is running (agent is busy)
- Clear suggestion when input is cleared or conversation switches
- No visual indicator while loading (it should feel invisible/instant)
- Swipe threshold: same 60pt as existing clear gesture

## Files to Modify

1. `CloudeShared/.../ClientMessage.swift` — add `autocomplete` case
2. `CloudeShared/.../ServerMessage.swift` — add `autocompleteResult` case
3. `CloudeShared/.../ServerMessage+Encoding.swift` — encode new case
4. `Cloude Agent/Services/AutocompleteService.swift` — **NEW** — Haiku API caller
5. `Cloude Agent/App/AppDelegate+MessageHandling.swift` — handle autocomplete
6. `Cloude/Services/ConnectionManager+API.swift` — send/receive autocomplete
7. `Cloude/UI/GlobalInputBar.swift` — ghost text + swipe right + debounce
8. `Cloude/UI/MainChatView.swift` — wire up callback with conversation context

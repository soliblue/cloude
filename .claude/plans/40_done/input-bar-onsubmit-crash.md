# Input Bar onSubmit Crash {exclamationmark.triangle}
<!-- build: 120 -->
<!-- priority: 8 -->
<!-- tags: ui, crash, swiftui -->

> The app can crash in the chat composer render path when the input field uses `.onSubmit`.

## Problem
After the recent UI test cleanup, the app started crashing during normal message testing. The crash happens in the chat composer path, not in networking or message send logic.

## Desired Outcome
The composer should support keyboard submit behavior without crashing, and normal launch plus message send should remain stable.

## Repro
1. Launch the app in Simulator
2. Open a fresh repo-rooted conversation
3. Switch the model to `haiku`
4. Send a normal message like `hello`
5. In the crashing version, the app can terminate with `SIGSEGV`

## Crash Evidence
- Crash report: `/Users/soli/Library/Logs/DiagnosticReports/Cloude-2026-03-29-105103.ips`
- Exception: `EXC_BAD_ACCESS / SIGSEGV`
- Faulting thread: main thread
- Top symbol in the relevant stack: `initializeWithCopy for OnSubmitModifier`
- Stack points into the composer render path around `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/UI/GlobalInputBar+InputRow.swift`

## What We Found
- The crash signature points at SwiftUI's `OnSubmitModifier`, not at the send pipeline itself.
- Removing only the `TextField` `.onSubmit` modifier stopped the crash in the same launch and send flow.
- After removing `.onSubmit`, the app rebuilt, launched, opened a new conversation, switched to `haiku`, and sent `hello` without generating a new crash report.
- The send button path still works.
- This suggests a SwiftUI composition issue or framework bug in this specific `TextField` setup rather than a bug in `onSend()` itself.

## Temporary Mitigation
Current local change removes this block from the composer `TextField`:

```swift
.onSubmit {
    if canSend { onSend() }
}
```

This avoids the crash but removes keyboard Return-to-send behavior.

## Current Hypothesis
The combination of `.onSubmit`, the vertically expanding `TextField`, and the composer view's captured state may be triggering a SwiftUI framework bug during view construction or modifier copying.

## Things to Try
- Reintroduce submit behavior through a different UI primitive or attachment point
- Test whether a single-line `TextField` still crashes with `.onSubmit`
- Test whether moving submit handling out of the current composer view changes the behavior
- Reduce captured state in the submit closure and see if the crash disappears
- Compare behavior with `.submitLabel(...)` and other keyboard-submit paths

## How to Test
1. Build and launch the app in Simulator
2. Open a new conversation
3. Switch to `haiku`
4. Send a short normal message
5. Confirm the app stays alive and the run enters `running`
6. If Return-to-send is reintroduced, explicitly test the keyboard submit path as well

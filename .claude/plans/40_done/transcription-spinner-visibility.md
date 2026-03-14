# Transcription Spinner Not Visible During Processing

<!-- build: 86 -->

## Problem
After stopping a voice recording, the transcription loading spinner wasn't showing. The audio waveform overlay disappeared and the input bar returned, with a gap of a few seconds before the transcription result appeared.

## Root Cause
`EnvironmentConnection.isTranscribing` changes weren't forwarded to `ConnectionManager.objectWillChange`, so SwiftUI never re-rendered `MainChatView` to show the `RecordingOverlayView` in its transcribing state.

## Fix
Added `didSet` on `isTranscribing` in `EnvironmentConnection.swift` to forward changes to the parent `ConnectionManager`, matching the pattern used by `ConversationOutput`.

# Small Fixes Plan

Quick wins and isolated improvements.

---

## Voice Message Resilience

**Goal:** Don't lose recordings if network fails.

**Implementation:**
1. Save recording to fixed path: `Documents/pending_audio.m4a`
2. On send success: delete file
3. On send failure: keep file, show resend button
4. On app launch: check if file exists, show resend option

**Files:**
- `Cloude/Cloude/Services/AudioRecorder.swift` - save to fixed path
- `Cloude/Cloude/UI/GlobalInputBar.swift` - resend button UI

**Complexity:** Moderate

---

## Compact Input Fields

**Goal:** Space-efficient pill-style inputs with label inside.

**Design:**
```
┌──────────────────────────────┐
│ Host │ 100.x.x.x             │
└──────────────────────────────┘
```

Instead of:
```
Host
┌──────────────────────────────┐
│ 100.x.x.x                    │
└──────────────────────────────┘
```

**Implementation:**
```swift
struct CompactTextField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
            Divider()
            TextField("", text: $text)
                .padding(.horizontal, 12)
        }
        .frame(height: 44)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

**Files:**
- New: `Cloude/Cloude/UI/CompactTextField.swift`
- `Cloude/Cloude/UI/SettingsView.swift` - use new component

**Complexity:** Trivial

---

## Tailscale Requirement Info

**Goal:** Show users that Tailscale is required.

**Implementation:**
- iOS Settings: Info section with text + link to tailscale.com/download
- Mac Agent menu: Status item showing Tailscale requirement

**Files:**
- `Cloude/Cloude/UI/SettingsView.swift` - add info section
- `Cloude/Cloude Agent/UI/StatusView.swift` - add menu item

**Complexity:** Trivial

---

## TTS Playback (Phase 1)

**Goal:** Long press message → play as audio.

**Implementation:**
1. Add context menu option "Play" to assistant messages
2. Use `AVSpeechSynthesizer` (built-in, offline)
3. Strip markdown before speaking
4. Show playing indicator

**Files:**
- `Cloude/Cloude/UI/ChatView+MessageBubble.swift` - context menu
- New: `Cloude/Cloude/Services/TTSService.swift` - speech synthesis

**Complexity:** Moderate

---

## Priority Order

1. **Tailscale info** - trivial, improves onboarding
2. **Compact input fields** - trivial, visual polish
3. **Voice resilience** - moderate, prevents frustration
4. **TTS playback** - moderate, nice to have

---

## Dependencies

- None of these depend on each other
- None conflict with Memory UI or Tool Display work
- Can be done in parallel by separate agent

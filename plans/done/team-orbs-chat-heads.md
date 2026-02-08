# Teammate Orbs → Chat Heads Redesign
<!-- priority: 10 -->
<!-- tags: teams, ui -->
<!-- build: 56 -->

## Context
The floating teammate orbs are status indicators only — you can't see what teammates are saying without opening a sheet. Messages are invisible in the main flow. This redesign turns orbs into mini chat heads: each orb shows the teammate's name, floats a speech bubble when a message arrives, and tapping opens a full message timeline.

## Changes

### 1. Add message history to TeammateInfo
**File**: `Cloude/CloudeShared/Sources/CloudeShared/Models/TeamTypes.swift`

- Add `TeammateMessage` struct (id, text, timestamp)
- Add `messageHistory: [TeammateMessage]` and `unreadCount: Int` to `TeammateInfo`
- Add explicit `CodingKeys` excluding the new fields (they're iOS-local state, not sent over the wire)
- Custom `init(from:)` to set defaults for the new fields
- Cap history at 50 messages per teammate

### 2. Accumulate messages instead of overwriting
**File**: `Cloude/Cloude/Services/ConnectionManager+API.swift`

- In `handleTeammateUpdate`: when a new message arrives, append to `messageHistory` and bump `unreadCount` (in addition to setting `lastMessage`/`lastMessageAt`)

### 3. Redesign TeammateOrb with name + speech bubble + unread badge
**File**: `Cloude/Cloude/UI/TeamOrbsOverlay.swift`

- **Name label**: small caption below each orb (always visible, truncated to ~6 chars)
- **Speech bubble**: when `lastMessage` changes, a floating bubble expands left from the orb showing the summary text (3 line limit). Auto-collapses after 5 seconds via a cancellable DispatchWorkItem timer. Animated with spring transition anchored to trailing edge.
- **Unread badge**: small colored dot on the orb when `unreadCount > 0` and bubble is not showing
- **onClearUnread callback**: passed from parent to reset unread count when detail sheet opens
- Layout: each orb row is an HStack — `[bubble (conditional)] [VStack: orb + name]` — so bubbles grow leftward naturally within the trailing-aligned ZStack

### 4. Upgrade detail sheet with message timeline
**File**: `Cloude/Cloude/UI/TeamOrbsOverlay+Detail.swift` (new, split from main file)

- **Header**: orb circle, name, model/agentType badges, status dot (same as now but cleaner)
- **Message timeline**: ScrollView + LazyVStack of all messages from that teammate, each with timestamp + text. Newest at bottom. Color accent from teammate color.
- **Empty state**: "No messages yet" when history is empty
- Follows standard sheet pattern: NavigationStack, xmark toolbar button, .ultraThinMaterial, .presentationDetents([.medium, .large])

### 5. Wire up callback in ConversationView
**File**: `Cloude/Cloude/UI/ConversationView.swift`

- Pass `onClearUnread` closure to `TeamOrbsOverlay` that resets `output?.teammates[idx].unreadCount = 0`

## No changes needed
- Mac Agent (RunnerManager, WebSocket) — no wire format changes
- ServerMessage — existing `teammateUpdate` message carries everything we need
- TeamBannerView / TeamDashboardSheet — left as-is for now

## Verification
1. Build with `source .env && fastlane mac build_agent`
2. Start a team session from CLI with 2+ teammates
3. Verify: orbs show names below them
4. Verify: when a teammate sends a message, speech bubble appears and auto-collapses after ~5s
5. Verify: unread dot appears after bubble collapses (if sheet wasn't opened)
6. Verify: tapping orb opens detail sheet with full message history
7. Verify: unread dot clears after opening detail sheet

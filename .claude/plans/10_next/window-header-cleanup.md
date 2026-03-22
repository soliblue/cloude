# Window Header Cleanup {rectangle.topthird.inset.filled}
<!-- priority: 9 -->
<!-- tags: ui -->

> Declutter the top of the app. Nav toolbar has redundant env icons and useless power button. Window header is packed with rarely-used action buttons. Strip both down.

## Current State

**Nav toolbar** (CloudeApp+MainContent.swift):
```
[StatusLogo]   (env●)(env●)   [⏻]
               ConvName - folder - $cost ˅
```
- Leading: StatusLogo (opens settings)
- Principal: env indicator buttons (line 1) + navTitlePill (line 2, single line)
- Trailing: power button (connect/disconnect all)

**Window header** (MainChatView+WindowHeader.swift):
```
[chat] [files] [git] [term]   ·   (env●)   ·   [copy] | [fork] | [↺] | [✕]
```

Long press on bottom bar window icon -> opens WindowEditSheet

## Target State

**Nav toolbar**:
```
[StatusLogo]              ConversationName
                          (env) folder - $cost
```
- Leading: StatusLogo (unchanged)
- Trailing: two-line navTitlePill, right-aligned (name on line 1, env symbol + folder + cost on line 2)
- Env symbol is purely decorative (no connection tracking, just shows the conversation's env icon)
- Env indicator buttons: removed
- Power button: removed

**Window header** (full-width segmented control):
```
[    chat    |   files   |    git    |   term   | ✕ ]
```
- Type buttons fill equal width across the screen, close button fixed-width at the end
- Dividers between each segment
- No env circle, no other action buttons

**Bottom bar window icon**:
- Tap: navigate (unchanged)
- Long press: context menu with Refresh, Export, Fork, Edit

## Detailed Changes

### 1. `Cloude/Cloude/App/CloudeApp+MainContent.swift`

**Remove power button toolbar item** (lines 34-47):
```swift
// DELETE entire ToolbarItem(placement: .topBarTrailing) block
```

**Move navTitlePill to trailing** (lines 31-33):
```swift
// CHANGE placement from .principal to .topBarTrailing
// CHANGE environmentIndicators to navTitlePill
ToolbarItem(placement: .topBarTrailing) {
    navTitlePill
}
```

**Keep `Combine` import** (line 2) - still needed for `.onReceive(connection.events, ...)` on line 50.

### 2. `Cloude/Cloude/App/CloudeApp+Toolbar.swift`

**Delete `environmentIndicators` computed property entirely** (lines 6-34). It wraps `navTitlePill` in a VStack with env icons. Since `navTitlePill` is now called directly from MainContent, the wrapper is dead.

**Rewrite `navTitlePill`** (lines 36-76) to two-line layout:
```swift
@ViewBuilder
var navTitlePill: some View {
    if !windowManager.isHeartbeatShowing {
        let conversation = windowManager.activeWindow?.conversation(in: conversationStore)
        Button(action: {
            NotificationCenter.default.post(name: .editActiveWindow, object: nil)
        }) {
            VStack(alignment: .trailing, spacing: 2) {
                if let conv = conversation {
                    Text(conv.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: conv.name)
                } else {
                    Text("Select chat...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    if let envId = conversation?.environmentId,
                       let env = environmentStore.environments.first(where: { $0.id == envId }) {
                        Image(systemName: env.symbol)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    if let folder = conversation?.workingDirectory?.nilIfEmpty?.lastPathComponent {
                        Text(folder)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if let conv = conversation, conv.totalCost > 0 {
                        Text("$\(String(format: "%.2f", conv.totalCost))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
```

Key differences from current:
- `HStack` -> `VStack(alignment: .trailing, spacing: 2)` for two lines
- Line 1: conversation name only
- Line 2: env symbol (decorative) + folder + cost (no `-` separators, just spacing)
- Remove `chevron.down` icon
- Remove `"- "` prefix from folder and cost text
- Env symbol uses `environmentStore` lookup (needs access, already available on CloudeApp)

**Keep `CloudeShared` import** (line 2) - still needed for env model types used in navTitlePill.

### 3. `Cloude/Cloude/UI/MainChatView+WindowHeader.swift`

**Rewrite entire file** - type switcher fills width as segmented control, close button at end:
```swift
import SwiftUI

extension MainChatView {
    func windowHeader(for window: ChatWindow, conversation: Conversation?) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(WindowType.allCases.enumerated()), id: \.element) { index, type in
                let envConnected = type == .chat || (conversation?.environmentId).flatMap({ connection.connection(for: $0)?.isConnected }) ?? false
                if index > 0 {
                    Divider()
                        .frame(height: 20)
                }
                Button(action: {
                    if envConnected { windowManager.setWindowType(window.id, type: type) }
                }) {
                    Image(systemName: type.icon)
                        .font(.system(size: 15, weight: window.type == type ? .semibold : .regular))
                        .foregroundColor(window.type == type ? .accentColor : .secondary)
                        .opacity(envConnected ? 1 : 0.3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
            }

            Divider()
                .frame(height: 20)

            Button(action: {
                windowManager.setActive(window.id)
                windowManager.removeWindow(window.id)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 7)
        .padding(.top, 0)
        .padding(.bottom, 7)
        .background(Color.themeSecondary)
    }
}
```

Key changes from current:
- Removed inner `HStack` wrapper - type buttons now in the outer HStack directly
- Each type button gets `.frame(maxWidth: .infinity)` to fill equal width
- Removed `.padding(.horizontal, 10)` from type buttons (width is now automatic)
- Divider between type switcher and close button
- Close button has fixed width with `.padding(.horizontal, 14)`
- Removed: env circle button (lines 29-47), second Spacer (line 49), entire right-side HStack except close (lines 51-136)

### 4. `Cloude/Cloude/UI/MainChatView+PageIndicator.swift`

**Replace long press on `windowIndicatorButton`** (lines 97-101):
```swift
// CHANGE FROM:
.simultaneousGesture(
    LongPressGesture().onEnded { _ in
        editingWindow = window
    }
)

// CHANGE TO:
.contextMenu {
    Button(action: {
        windowManager.setActive(window.id)
        refreshTrigger.toggle()
        refreshConversation(for: window)
    }) {
        Label("Refresh", systemImage: "arrow.clockwise")
    }
    Button(action: {
        if let conv = conversation {
            exportConversation(conv)
        }
    }) {
        Label("Export", systemImage: "doc.on.doc")
    }
    Button(action: {
        if let conv = conversation, conv.sessionId != nil {
            windowManager.setActive(window.id)
            if let newConv = conversationStore.duplicateConversation(conv) {
                windowManager.linkToCurrentConversation(window.id, conversation: newConv)
            }
        }
    }) {
        Label("Fork", systemImage: "arrow.triangle.branch")
    }
    Divider()
    Button(action: {
        editingWindow = window
    }) {
        Label("Edit", systemImage: "pencil")
    }
}
```

Note: keep "Edit" in the context menu so WindowEditSheet is still accessible (previously long press opened it).

### 5. `Cloude/Cloude/UI/MainChatView.swift` - State cleanup

**Remove `exportCopied` state** (line 33):
```swift
// DELETE: @State var exportCopied = false
```
No longer needed - export moves to context menu, no inline checkmark animation.

**Keep `refreshTrigger`** (line 32) - still used by context menu refresh action.

**Keep `refreshingSessionIds`** (line 31) - still used by `refreshConversation` and event handling.

### 6. `Cloude/Cloude/UI/MainChatView+ConversationInfo.swift` - Dead code check

`WindowHeaderView` is used in `ConversationView.swift:51` with `showHeader` (defaults false, never set true). **Both `WindowHeaderView` and `ConversationInfoLabel` appear unused in practice.**

Decision: leave them for now. They're small standalone structs. Removing unused code is a separate ticket. This cleanup focuses on the header.

### 7. `Cloude/Cloude/App/CloudeApp+Actions.swift` - Dead code check

`connectAllConfiguredEnvironments()` at line 46 is only called from the power button (CloudeApp+MainContent.swift:39). Once the power button is removed, this function becomes dead code.

**Delete `connectAllConfiguredEnvironments()`** from CloudeApp+Actions.swift.

## What Stays Untouched

- `MainChatView+WindowActions.swift` - `exportConversation`, `refreshConversation`, `environmentDisconnected` all still used (input section uses refresh, context menu uses export/fork)
- `MainChatView.swift` states: `refreshTrigger`, `refreshingSessionIds` still used
- `MainChatView+EventHandling.swift` - handles `refreshingSessionIds.remove`
- `hasEnvironmentMismatch` on MainChatView - still used by input section
- `activeEnvConnection` on MainChatView - verify usage separately
- `ConversationView.swift` `showHeader` path - unused but separate concern

## Files Changed (7)
1. `Cloude/Cloude/App/CloudeApp+MainContent.swift` - remove power button, change principal to trailing
2. `Cloude/Cloude/App/CloudeApp+Toolbar.swift` - delete env indicators, rewrite navTitlePill to two lines
3. `Cloude/Cloude/App/CloudeApp+Actions.swift` - delete `connectAllConfiguredEnvironments()`
4. `Cloude/Cloude/UI/MainChatView+WindowHeader.swift` - strip to type switcher + close
5. `Cloude/Cloude/UI/MainChatView+PageIndicator.swift` - long press -> context menu
6. `Cloude/Cloude/UI/MainChatView.swift` - remove `exportCopied` state

## Tasks

### Nav toolbar
- [ ] Remove power button `ToolbarItem(placement: .topBarTrailing)` from `CloudeApp+MainContent.swift`
- [ ] Move `navTitlePill` placement from `.principal` to `.topBarTrailing` in `CloudeApp+MainContent.swift`
- [ ] Delete `environmentIndicators` computed property from `CloudeApp+Toolbar.swift`
- [ ] Rewrite `navTitlePill` to two-line VStack (name line 1, env symbol + folder + cost line 2) in `CloudeApp+Toolbar.swift`
- [ ] Delete `connectAllConfiguredEnvironments()` from `CloudeApp+Actions.swift`

### Window header
- [ ] Rewrite `MainChatView+WindowHeader.swift`: equal-width type buttons + dividers + fixed-width close button
- [ ] Remove env circle, copy, fork, refresh buttons from header

### Bottom bar
- [ ] Replace `.simultaneousGesture(LongPressGesture)` with `.contextMenu` on `windowIndicatorButton` in `MainChatView+PageIndicator.swift`
- [ ] Add Refresh, Export, Fork, Divider, Edit items to context menu
- [ ] Remove `exportCopied` state from `MainChatView.swift`

## Risk

- Low. All removed functionality is either relocated (to context menu) or redundant (env icons, power button).
- `connectAllConfiguredEnvironments` confirmed no other callers (only power button).
- Context menu UX is standard iOS, no custom gesture handling needed.

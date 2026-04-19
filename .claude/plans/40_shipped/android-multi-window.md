---
title: "Android Multi-Window System"
description: "Swipeable window tabs (chat/files/git) with HorizontalPager, tab bar, and page indicator."
created_at: 2026-03-28
tags: ["android", "ui", "windows"]
icon: rectangle.on.rectangle
build: 120
---
# Android Multi-Window System


## Background

Currently Android uses boolean flags (`showFiles`, `showGit`) in MainActivity to swap between ChatScreen, FileBrowserScreen, and GitScreen as separate full-screen views with a back arrow. iOS has a proper window system with swipeable pages, a tab bar to switch content type, and a page indicator.

## Goals
- HorizontalPager with swipeable windows (chat, files, git)
- Tab bar to switch window content type without swiping
- Page indicator showing window icons/titles
- Add/remove windows (max 5)
- Persist window state across app restarts

## Implementation Plan

### Step 1: Window Model (`Models/ChatWindow.kt`)
```kotlin
enum class WindowType { Chat, Files, GitChanges }

data class ChatWindow(
    val id: String = UUID.randomUUID().toString(),
    val type: WindowType = WindowType.Chat,
    val conversationId: String? = null
)
```

### Step 2: WindowManager (`Services/WindowManager.kt`)
State holder using SharedPreferences for persistence:
- `windows: StateFlow<List<ChatWindow>>` (default: single chat window)
- `activeWindowIndex: StateFlow<Int>`
- `addWindow()`, `removeWindow(id)`, `setWindowType(id, type)`
- `setActive(index)`, `navigateLeft()`, `navigateRight()`
- Save/restore via SharedPreferences JSON

### Step 3: Window Tab Bar (`UI/chat/WindowTabBar.kt`)
Horizontal row of 3 icons: Chat | Files | Git
- Current type highlighted in Accent
- Tapping switches the active window's content type
- Files & Git icons dimmed if no environment connected

### Step 4: Page Indicator (`UI/chat/PageIndicator.kt`)
Horizontal row below tab bar:
- Window dots/icons showing type (chat bubble, folder, diff)
- Active window highlighted
- Tap to navigate to window
- Plus button to add window (if < 5)
- Long-press for delete option

### Step 5: Main Screen Refactor (`UI/chat/MainScreen.kt`)
New composable that replaces the when-block in MainActivity:
- Contains HorizontalPager wrapping window content
- Each page renders ChatScreen, FileBrowserScreen, or GitScreen based on window type
- Tab bar above content, page indicator below tab bar
- Remove `showFiles`/`showGit` booleans from MainActivity

### Step 6: MainActivity Integration
- Replace the current when-block with `MainScreen`
- Remove Files/Git toolbar buttons (now in tab bar)
- Keep Settings, Deploy, Conversations in toolbar
- Pass WindowManager to MainScreen

## File Changes

**New files:**
- `android/.../Models/ChatWindow.kt` - WindowType enum + ChatWindow data class
- `android/.../Services/WindowManager.kt` - Window state management
- `android/.../UI/chat/WindowTabBar.kt` - Type switching tab bar
- `android/.../UI/chat/PageIndicator.kt` - Window dots + add button
- `android/.../UI/chat/MainScreen.kt` - HorizontalPager container

**Modified files:**
- `android/.../App/MainActivity.kt` - Replace when-block, remove showFiles/showGit

**No changes to:**
- `ChatScreen.kt`, `FileBrowserScreen.kt`, `GitScreen.kt` - used as-is inside pager pages

## Edge Cases
- Single window: tab bar still visible, no page indicator dots
- Environment disconnected: files/git tabs show placeholder
- Window removal: if active window removed, activate previous
- Conversation switch: only affects windows with matching conversationId

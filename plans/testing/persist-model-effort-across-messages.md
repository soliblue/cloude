# Persist Model & Effort Across Messages

**Problem**: When you change model/effort in the send button menu, the selection doesn't persist:
- Selections reset after sending a message
- Selections don't restore when switching conversations/windows
- GlobalInputBar has its own local state instead of binding to parent

**Root Cause**:
1. GlobalInputBar uses `@State` for `currentEffort`/`currentModel` instead of `@Binding`
2. No initialization from conversation's `defaultEffort`/`defaultModel`
3. Draft save/restore logic only handles text + images, not effort/model

**Solution**:
1. Change GlobalInputBar to use `@Binding` instead of `@State` for effort/model
2. Update MainChatView to initialize from conversation defaults on window switch
3. Include effort/model in the draft save/restore logic

**Files**:
- `Cloude/Cloude/UI/GlobalInputBar.swift` - Change to @Binding
- `Cloude/Cloude/UI/MainChatView.swift` - Add draft logic for effort/model, initialize from conversation defaults

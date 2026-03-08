# Remove Extra Top Padding on Input Bar

Removed the 12pt top padding above the input bar (`.padding(.vertical, 12)` → `.padding(.bottom, 12)`). The gap between the chat content and input bar was unnecessary.

**File:** `GlobalInputBar.swift` line 229

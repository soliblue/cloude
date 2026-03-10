# File Reference Fix (@mention)

Fixed two issues preventing file references from working in the input bar:

1. **`selectFile`** inserted only the filename (`CLAUDE.md`) instead of the full path - Claude Code needs the full path to reference files
2. **`atMentionQuery`** had a `hasExtension` check that hid suggestions as soon as the user typed a dot (e.g. `@CLAUDE.m` killed suggestions)

**Files changed:** `Cloude/Cloude/UI/GlobalInputBar.swift`

# Fix file preview environment routing {arrow.triangle.swap}
<!-- priority: 10 -->
<!-- tags: file-preview, env -->

> Fixed file preview routing to wrong environment by using window-specific environment ID.

## Problem
File preview was routing to the wrong environment (e.g. "medine" instead of "work") when multiple environments are connected. Only reproducible with 2+ environments.

## Root cause
`MainChatView+Messaging.swift` used `environmentStore.activeEnvironmentId` (global picker) instead of `activeWindowEnvironmentId()` (window-specific) when creating conversations on first message send.

## Fix
Changed lines 93 and 99 in `MainChatView+Messaging.swift` to use `activeWindowEnvironmentId()`, matching what all other conversation creation paths already do.

## Test
1. Connect to two environments
2. Open a conversation in the non-active environment
3. Send a message, then click a file path pill
4. Verify file preview loads from the correct environment

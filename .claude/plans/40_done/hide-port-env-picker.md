# Hide Port from Environment Picker
<!-- build: 86 -->

Remove port number from the empty chat view environment picker - just show the hostname.

## Changes
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/UI/ConversationView+EmptyState.swift`: Removed `:\(env.port)` from both the menu item and the selected label

## Test
- Open a new conversation (empty state)
- Environment picker should show just the hostname (e.g. `cloude-home.soli.blue`) without `:8765`

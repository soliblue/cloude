# Hide Port from Environment Picker {network}
<!-- priority: 10 -->
<!-- tags: ui, env -->
<!-- build: 86 -->

> Removed port number from environment pickers, showing only hostname.

## Changes
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/UI/ConversationView+EmptyState.swift`: Removed port from empty state picker
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/UI/WindowEditSheet+Form.swift`: Removed port from window edit sheet picker, menu items, and read-only environment row

## Test
- Open a new conversation (empty state) - picker shows hostname only
- Open window edit sheet - environment picker and row show hostname only

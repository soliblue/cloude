# Hide Port from Environment Picker
<!-- build: 86 -->

Remove port number from environment pickers everywhere - just show the hostname.

## Changes
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/UI/ConversationView+EmptyState.swift`: Removed port from empty state picker
- `/Users/soli/Desktop/CODING/cloude/Cloude/Cloude/UI/WindowEditSheet+Form.swift`: Removed port from window edit sheet picker, menu items, and read-only environment row

## Test
- Open a new conversation (empty state) - picker shows hostname only
- Open window edit sheet - environment picker and row show hostname only

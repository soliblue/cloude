# Plan Context Injection {doc.text.magnifyingglass}
<!-- priority: 3 -->
<!-- tags: ui, plans, chat -->

> Search results include plan tickets — tapping a plan injects its content into the chat context.

## Problem

Plans contain valuable context (architecture decisions, implementation details) but live in files. When chatting, you'd have to manually reference them. Should be seamless.

## Plan

- Search (from conversation-search) also indexes plan files
- Plan results show title + stage (next/active/done)
- Tapping a plan injects its markdown content into the current chat input or context
- Details TBD when we get to implementation

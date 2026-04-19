---
title: "Remove Auto-Scroll on Send"
description: "Removed the forced scroll-to-bottom when new messages arrive."
created_at: 2026-03-28
tags: ["ui", "messages", "cleanup"]
icon: arrow.down.to.line
build: 120
---


# Remove Auto-Scroll on Send
Removed the `.onChange(of: messages.last?.id)` block in `ConversationView+MessageScroll.swift` that called `scrollPos.scrollTo(edge: .bottom)` on every new message. `.defaultScrollAnchor(.bottom)` still anchors new conversations at the bottom.

**Files:** `Cloude/Cloude/UI/ConversationView+MessageScroll.swift`

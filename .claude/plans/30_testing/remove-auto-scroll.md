# Remove Auto-Scroll on Send {arrow.down.to.line}
<!-- build: 120 -->
<!-- priority: 10 -->
<!-- tags: ui, messages, cleanup -->

> Removed the forced scroll-to-bottom when new messages arrive.

Removed the `.onChange(of: messages.last?.id)` block in `ConversationView+MessageScroll.swift` that called `scrollPos.scrollTo(edge: .bottom)` on every new message. `.defaultScrollAnchor(.bottom)` still anchors new conversations at the bottom.

**Files:** `Cloude/Cloude/UI/ConversationView+MessageScroll.swift`

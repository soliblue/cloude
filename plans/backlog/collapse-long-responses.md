# Collapse Long Previous Responses

## Problem
In a conversation, older responses that are 10+ lines long take up a lot of vertical space. Scrolling through a long conversation means wading through walls of text from earlier exchanges that you've already read.

## Idea
Auto-collapse previous assistant responses that exceed ~10 lines, showing just the first few lines with a "Show more" tap target. The current/latest response always stays fully expanded.

## Open Questions
- What's the right line threshold? 10 lines? 15?
- Should it be line-based or height-based (some lines wrap)?
- Tap to expand one message, or "expand all" option?
- Should user messages also collapse, or only assistant responses?
- How to handle code blocks — collapse the whole message or just the code?
- Should expanded state persist or reset on scroll?
- What about tool results — collapse those separately?

## Complexity
Medium — needs careful measurement of rendered content height, smooth expand/collapse animations, and state tracking per message. The tricky part is measuring "lines" in rendered markdown with variable font sizes, code blocks, and tool pills.

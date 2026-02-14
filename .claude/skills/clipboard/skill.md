---
name: clipboard
description: Read and write the Mac clipboard. See what was last copied, or copy text to clipboard.
user-invocable: true
icon: doc.on.clipboard
aliases: [paste, copy, pasteboard]
---

# Clipboard Skill

Read/write the Mac system clipboard. No permissions needed.

## Usage

```bash
bash .claude/skills/clipboard/clip.sh                    # Read current clipboard
bash .claude/skills/clipboard/clip.sh write "some text"   # Write to clipboard
```

Note: `cloude clipboard` copies to the **iOS** clipboard. This skill accesses the **Mac** clipboard.

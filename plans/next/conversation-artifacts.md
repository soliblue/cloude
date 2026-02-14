# Conversation Artifacts

## Problem
When Claude generates substantial content (travel plans, code, documents, analysis), it gets lost in chat scroll. No way to track, revisit, or iterate on generated outputs.

## Inspiration
Anthropic's Claude.ai has "artifacts" — standalone panels for generated content that you can copy, iterate on, and download. We need something similar for Cloude.

## Questions to Answer
- Does Claude Code CLI have native artifact support? (check `--output`, file writing conventions, any artifact protocol)
- If not, what's the minimal build? Options:
  - Write artifacts to a temp file, show as file preview in chat
  - Dedicated artifact view/tab in the window
  - Markdown files in a conversation-specific directory
- How do artifacts relate to existing file preview (FilePreviewView)?
- Should artifacts be persistent (saved to disk) or ephemeral (session-only)?
- Versioning: can you iterate on an artifact ("update the Morocco plan to skip Essaouira")?

## Possible Approaches
- **A: File-based** — write to `~/.cloude/artifacts/{conv-id}/` as markdown/code files, render via existing file preview
- **B: Message metadata** — tag certain assistant messages as artifacts, render differently in chat (expandable, copyable, pinnable)
- **C: Dedicated tab** — new tab type alongside chat/files/git that shows all artifacts for the window
- **D: Hybrid** — artifacts are files on disk but surfaced in a dedicated UI with iteration support

## Scope
- Research CLI capabilities first
- Design the minimal version that solves "I generated a big plan, where did it go?"
- Keep it simple — don't overbuild

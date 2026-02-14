---
name: consult
description: Get a second opinion from another AI — Codex (OpenAI) or a different Claude model (Haiku, Sonnet, Opus). One skill, multiple brains. Read-only.
user-invocable: true
icon: person.2.wave.2
aliases: [ask, second-opinion, secondbrain, codex, consult-codex, consult-haiku, consult-sonnet, consult-opus]
---

# Consult

Get a second opinion from another AI. Routes to Codex (OpenAI) or a different Claude model depending on what you ask.

## Routing

Parse the user's input for a model hint:

| Hint | Engine | Command |
|------|--------|---------|
| `codex`, `openai`, `gpt` | Codex | `codex exec -s read-only` |
| `haiku` | Claude Haiku | `claude -p --model haiku` |
| `sonnet` | Claude Sonnet | `claude -p --model sonnet` |
| `opus` | Claude Opus | `claude -p --model opus` |
| *(no hint)* | Claude Sonnet | `claude -p --model sonnet` |

Model hints can appear anywhere: "/consult haiku: is this right?", "/consult ask codex about auth", "/consult opus review this".

## Commands

**Claude models:**
```bash
claude -p --model <model> --tools "Read,Glob,Grep,WebFetch,WebSearch" --dangerously-skip-permissions "QUESTION"
```

**Codex:**
```bash
codex exec -s read-only -C "$(git rev-parse --show-toplevel)" "QUESTION"
```

## Instructions

1. Take the user's question from the `/consult` arguments
2. Detect which engine to use from the routing table above
3. Strip the model hint from the question before passing it
4. Run the appropriate command
5. **CRITICAL: Set a 5-minute timeout** on the Bash call (`timeout: 300000`)
6. Present the response, clearly noting which model answered (e.g. "**Sonnet says:**")
7. Optionally compare with your own perspective if useful

## Examples

```
/consult what's wrong with this approach?          → Sonnet (default)
/consult haiku: quick check on this function       → Haiku
/consult opus review the chat architecture         → Opus
/consult codex how would you handle auth here?     → Codex
/consult ask openai about this pattern             → Codex
```

## Notes

- All engines get read-only access — they can explore but not modify
- Claude models get the same codebase context (working directory + CLAUDE.md)
- Codex gets the workspace via `-C` flag
- Good for: sanity checks, alternative approaches, catching blind spots, architecture reviews
- Default is Sonnet because it's the best balance of speed and quality for second opinions

---
name: codex
description: Get a second opinion from Codex (OpenAI) on a question or code problem. Use for second opinions, alternative approaches, or comparing perspectives.
user-invocable: true
icon: brain.head.profile
aliases: [ask-codex, openai, second-opinion]
---

# Ask Codex

Get Codex's opinion on something. Useful for second opinions, alternative approaches, or comparing perspectives.

## Usage

Run `codex exec` with the question, using read-only sandbox (no writes) and the current workspace:

```bash
codex exec -s read-only -C /Users/soli/Desktop/CODING/cloude "YOUR QUESTION HERE"
```

## Instructions

1. Take the user's question (from the `/codex` invocation arguments, or ask if not provided)
2. Run `codex exec` with `-s read-only` to keep it safe
3. Present Codex's response back to the user
4. If the user wants, compare it with your own perspective

## Notes

- Always use `-s read-only` to prevent Codex from modifying files
- Keep questions focused and specific for better responses
- Codex has access to read the codebase so it can give context-aware answers
- The workspace path is always the current project root

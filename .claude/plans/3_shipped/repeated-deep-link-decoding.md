---
title: "Repeated Deep Link Decoding"
description: "Decode simulator and app deep link query values that arrive percent-encoded more than once."
created_at: 2026-05-10
updated_at: 2026-05-10
tags: ["ui"]
icon: link
---

# Repeated Deep Link Decoding

## Implementation

The deep link router now repeatedly decodes percent escapes while preserving UTF-8 bytes directly, so query values that were encoded more than once become plain text before the route handler uses them.

This specifically protects simulator message sending and setup routes where prompts with spaces, newlines, and markdown can arrive as nested escaped strings.

## Verify

- Send a simulator deep link containing spaces, newlines, and markdown syntax.
- Confirm the stored user message is plain text rather than `%20` or `%0A` escaped text.
- Run the performance scenario and confirm it prints `prompt_decode=plain`.

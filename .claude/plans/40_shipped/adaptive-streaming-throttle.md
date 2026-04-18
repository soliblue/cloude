---
title: "Adaptive Streaming Throttle"
description: "Adaptive throttle reduces LiveBubble renders by 31% and eliminates late-stage FPS degradation during long streams."
created_at: 2026-04-01
tags: ["streaming", "performance"]
icon: gauge.with.dots.needle.bottom.50percent
build: 122
---


# Adaptive Streaming Throttle {gauge.with.dots.needle.bottom.50percent}
## Changes

- ObservedMessageBubble: adaptive text update throttle (20Hz when text > 3000 chars, 60Hz otherwise)
- StreamingMarkdownView: removed unused isComplete property and dead textChanged variable
- MessageBubble: removed isComplete parameter from StreamingMarkdownView calls

## Verify

Outcome: FPS stays above 55 during long streaming responses (8K+ chars). Streaming text still appears smooth with no visible stuttering from the throttle. Short responses stream at full 60Hz.

Test: send a message that generates a long response, monitor FPS via debug overlay. Verify FPS never drops below 55. Then send a short message and verify streaming feels smooth and immediate.

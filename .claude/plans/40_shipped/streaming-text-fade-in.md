---
title: "Streaming Text Fade-In"
description: "Added smooth character fade-in animation during streaming using contentTransition interpolate."
created_at: 2026-03-01
tags: ["streaming", "ui"]
icon: text.append
build: 82
---


# Streaming Text Fade-In
**Status**: Testing
**Created**: 2026-03-01

## Summary
Characters fade in smoothly from left to right during streaming instead of appearing abruptly.

## Implementation
- Added `.contentTransition(.interpolate)` to `Text` views in `StreamingBlockView` (both `.text` and `.header` cases)
- Added `.animation(.easeOut(duration: 0.15), value: text)` on `StreamingMarkdownView` body, conditional on `!isComplete` so completed messages don't animate
- SwiftUI's interpolate transition morphs text content — existing characters stay in place, new characters fade/morph in

## Files Changed
- `Cloude/Cloude/UI/StreamingMarkdownView.swift`

---
title: "Streaming Text Fade-In Animation"
description: "Add a smoother reveal to streaming text so new characters do not appear at full opacity instantly."
created_at: 2026-03-24
tags: ["ui", "markdown"]
icon: text.badge.star
build: 103
---


# Streaming Text Fade-In Animation {text.badge.star}
## Problem

The drip rate is correct, but each new chunk appears fully opaque. The result feels abrupt instead of fluid.

## What Failed

SwiftUI animation and content-transition attempts were not reliable enough, especially inside the unified streaming structure.

## Best Current Direction

Use deterministic trailing-character opacity rather than relying on implicit SwiftUI animation.

### Likely implementation
- track a fade edge near the tail of the displayed text
- make the newest characters partially transparent
- let them become fully opaque as streaming advances

## Why this direction

- does not depend on fragile implicit animation behavior
- keeps unified streaming intact
- should be easier to reason about than repeated animation restarts

## Verification

- new text fades in instead of popping in
- markdown colors are not broken
- layout does not jump while streaming

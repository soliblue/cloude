---
title: "Shimmer Overflow Fix"
description: "Fixed shimmer gradient overflowing tool pill bounds by adding a clip shape."
created_at: 2026-03-01
tags: ["tool-pill", "ui"]
icon: rectangle.dashed
build: 82
---


# Shimmer Overflow Fix
Shimmer gradient on executing tool pills overflows beyond the pill bounds. The `ShimmerOverlay` phase goes up to 1.5x width with no clip shape to contain it.

Fix: Add `.clipShape(RoundedRectangle(cornerRadius: 8))` to match the glass effect shape.

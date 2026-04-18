---
title: "Recording Overlay Fixed Height"
description: "Give the recording waveform container a fixed height so the overlay stays stable while the bars animate."
created_at: 2026-03-27
tags: ["input", "ui"]
icon: circle.fill
build: 115
---


# Recording Overlay Fixed Height
Audio waveform container now has a fixed height (`DS.Size.row`) so the recording overlay doesn't jump around as bars animate.

## Test
- Start recording and watch the overlay
- Confirm it stays stable (no vertical shifting)
- Bars should still animate within the fixed container

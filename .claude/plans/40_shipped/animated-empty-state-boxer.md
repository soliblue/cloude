---
title: "Animated Empty State - Boxer"
description: "Added animated boxer pixel art character to empty chat state using GIF player via UIViewRepresentable."
created_at: 2026-03-14
tags: ["ui"]
icon: figure.boxing
build: 86
---


# Animated Empty State - Boxer {figure.boxing}
Generated a new boxer pixel art character matching the style of the other 3 (painter, builder, explorer) using Gemini image generation. Then used Google Veo 3.0 image-to-video to create an 8-second boxing idle animation on green screen. Chroma keyed the green background, optimized with gifsicle (128 colors, O3), and integrated into the empty chat state.

## Changes
- Restyled boxer character to match other pixel Claudes (same orange body, proportions)
- Created `AnimatedGIFView.swift` - UIKit-based GIF player via `UIViewRepresentable`
- Added `claude-boxer-anim.gif` (2.8MB) to `Resources/`
- Empty state plays animation once when boxer is selected, stops on last frame
- Removed scientist, chef, ninja, artist characters from assets

## Files
- `Cloude/Cloude/UI/AnimatedGIFView.swift` (new)
- `Cloude/Cloude/UI/ConversationView+EmptyState.swift` (modified)
- `Cloude/Cloude/Resources/claude-boxer-anim.gif` (new)

## Known Issues
- GIF sizing may need adjustment (UIImageView not respecting SwiftUI frame constraints)
- 2.8MB is large for an app asset - could reduce frames or resolution

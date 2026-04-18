---
title: "Page Indicator Vertical Alignment Fix"
description: "Fixed misaligned icons in the bottom switcher bar with unified vertical structure."
created_at: 2026-02-08
tags: ["ui"]
icon: arrow.up.and.down
build: 66
---


# Page Indicator Vertical Alignment Fix {arrow.up.and.down}
Fixed misaligned icons in the bottom switcher bar. Heart, window SF symbols, dots, plus button now all share the same vertical structure (22pt icon frame + 5pt unread dot space).

## What broke
Icons had different heights — SF symbols in a VStack with unread dot, heart in a ZStack without, plus had no wrapper. Small circle dots were shorter than SF symbol icons.

## How to test
- Look at the bottom switcher bar
- Heart icon, window icons (SF symbols or dots), and plus button should all be vertically centered on the same line
- No icon should sit higher or lower than the others

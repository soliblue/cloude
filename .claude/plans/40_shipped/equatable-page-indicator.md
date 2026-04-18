---
title: "Equatable PageIndicator"
description: "Extract PageIndicator as equatable view, reducing renders from 14 to 3 per stream."
created_at: 2026-04-01
tags: ["ui", "performance"]
icon: gauge.with.dots.needle.bottom.50percent
build: 122
---


# Equatable PageIndicator {gauge.with.dots.needle.bottom.50percent}
## Changes

- Extracted page indicator from inline ViewBuilder function to separate PageIndicatorView struct
- Pre-computes display data (window names, streaming states) as Equatable WindowItem array
- Custom Equatable conformance ignores closures, only compares visible data
- Uses .equatable() modifier to skip body evaluation when content unchanged

## Verify

Outcome: page indicator tabs display correctly with proper active highlighting, streaming pulse animation, and window switching via tap and swipe. Long press opens edit sheet.

Test: open a conversation, send a message and confirm the streaming pulse appears on the active tab. Switch between windows by tapping tabs. Long press a tab to verify the edit sheet opens. Check debug overlay for PageIndicator render count (should be ~3 per stream).

# Page Indicator Vertical Alignment Fix
<!-- build: 66 -->

Fixed misaligned icons in the bottom switcher bar. Heart, window SF symbols, dots, plus button now all share the same vertical structure (22pt icon frame + 5pt unread dot space).

## What broke
Icons had different heights — SF symbols in a VStack with unread dot, heart in a ZStack without, plus had no wrapper. Small circle dots were shorter than SF symbol icons.

## How to test
- Look at the bottom switcher bar
- Heart icon, window icons (SF symbols or dots), and plus button should all be vertically centered on the same line
- No icon should sit higher or lower than the others

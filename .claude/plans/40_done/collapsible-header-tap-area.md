# Collapsible Header Tap Area {hand.tap}
<!-- priority: 10 -->
<!-- tags: ui, windows -->
<!-- build: 56 -->

> Made entire heading row tappable for collapse/expand instead of just the small chevron arrow.

## Problem
Collapsible section headers only collapsed when tapping the small chevron arrow — too small a hit target.

## Solution
Moved `contentShape(Rectangle())` and `onTapGesture` from the chevron to the entire `HStack`, so tapping anywhere on the heading row toggles collapse.

## Files Changed
- `Cloude/Cloude/UI/StreamingMarkdownView.swift` — `HeaderSectionView`

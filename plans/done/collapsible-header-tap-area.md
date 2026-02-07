# Collapsible Header Tap Area

## Problem
Collapsible section headers only collapsed when tapping the small chevron arrow — too small a hit target.

## Solution
Moved `contentShape(Rectangle())` and `onTapGesture` from the chevron to the entire `HStack`, so tapping anywhere on the heading row toggles collapse.

## Files Changed
- `Cloude/Cloude/UI/StreamingMarkdownView.swift` — `HeaderSectionView`

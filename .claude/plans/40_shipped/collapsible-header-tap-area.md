---
title: "Collapsible Header Tap Area"
description: "Made entire heading row tappable for collapse/expand instead of just the small chevron arrow."
created_at: 2026-02-07
tags: ["ui", "windows"]
icon: hand.tap
build: 47
---


# Collapsible Header Tap Area
## Problem
Collapsible section headers only collapsed when tapping the small chevron arrow — too small a hit target.

## Solution
Moved `contentShape(Rectangle())` and `onTapGesture` from the chevron to the entire `HStack`, so tapping anywhere on the heading row toggles collapse.

## Files Changed
- `Cloude/Cloude/UI/StreamingMarkdownView.swift` — `HeaderSectionView`

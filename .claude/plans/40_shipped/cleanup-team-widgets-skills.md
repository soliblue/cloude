---
title: "Cleanup: Remove Team UI, Demo Widgets, and Unused Skills"
description: "Remove unused team UI, demo widgets, and dormant skills to shrink the codebase and reduce context load."
created_at: 2026-03-26
tags: ["cleanup", "widget", "skills"]
icon: scissors
build: 114
---


# Cleanup: Remove Team UI, Demo Widgets, and Unused Skills
Removed unused features to reduce complexity and context load.

## Team UI (20 files, ~1500 lines)
- Removed custom team orbs, banners, dashboard, detail sheets
- Removed team polling, parsing, callbacks, TeamTypes

## Demo Widgets (13 files, ~1200 lines)
- Removed: quiz, flashcards, fill-in-blank, ordering, matching, categorization, word scramble, sentence builder, highlight, error correction, type answer, step reveal
- Kept: timeline, tree, function plot, interactive function, charts, color palette, image carousel

## Unused Skills (26 skills, ~8000 lines)
- Removed Apple integrations + video, weather, travel, tweets, moltbook, etc.
- Kept 15 dev-flow skills

## Total: 139 files, ~10,900 lines deleted

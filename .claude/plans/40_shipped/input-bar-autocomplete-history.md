---
title: "Input Bar Autocomplete History"
description: "Added autocomplete suggestions based on previously sent messages stored locally."
created_at: 2026-03-13
tags: ["input", "ui"]
icon: clock.arrow.circlepath
build: 86
---


# Input Bar Autocomplete History
- Autocomplete suggestions based on previously sent messages
- Local/on-device storage via UserDefaults for instant speed
- Only saves messages under 50 chars, skips slash commands
- Shows matching suggestions as horizontal pills above the input bar
- Tapping a suggestion fills the input field
- Keeps last 50 unique messages, deduplicates case-insensitively

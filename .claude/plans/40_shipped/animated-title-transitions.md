---
title: "Animated Title Transitions"
description: "Animated conversation name and symbol changes in the header pill with numericText and symbolEffect transitions."
created_at: 2026-03-03
tags: ["ui", "header"]
icon: textformat.abc
build: 82
---


# Animated Title Transitions
Animate conversation name and symbol changes in the header pill instead of instant swap.

## Changes
- `MainChatView+ConversationInfo.swift`: Added `.contentTransition(.numericText())` on name text and `.contentTransition(.symbolEffect(.replace))` on SF Symbol icon

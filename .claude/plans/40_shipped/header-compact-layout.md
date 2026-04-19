---
title: "Header Compact Layout"
description: "Fix header truncation by removing branch text and reducing tab padding."
created_at: 2026-02-06
tags: ["ui", "windows"]
icon: rectangle.compress.vertical
build: 34
---


# Header Compact Layout
Reduce header cramping when cost info is shown. Right side content (conversation name, folder, cost) was getting truncated.

## Changes
- Removed branch name text from git tab button (icon only, like chat and folder tabs)
- Reduced tab button padding from 7pt to 4pt

## Files
- Cloude/Cloude/UI/MainChatView.swift

---
title: "Fork Button Always Visible"
description: "Made fork button always visible in header, disabled when chat is empty."
created_at: 2026-03-09
tags: ["ui", "header"]
icon: arrow.triangle.branch
build: 82
---


# Fork Button Always Visible
## Problem
The fork/branch button in the top right header is completely hidden when the chat is empty. It should always be visible but disabled when there's nothing to fork.

## Solution
- Always show the fork button in the header
- When chat is empty, keep it visible but disabled (grayed out, non-interactive)
- When chat has messages, enable it as normal

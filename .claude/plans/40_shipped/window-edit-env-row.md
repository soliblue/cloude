---
title: "Window Edit Sheet - Environment Row Cleanup"
description: "Compacted environment info row to show host:port on left and truncated working directory on right."
created_at: 2026-03-09
tags: ["ui", "settings"]
icon: rectangle.compress.vertical
build: 82
---


# Window Edit Sheet - Environment Row Cleanup {rectangle.compress.vertical}
Compact the environment info row in WindowEditSheet+Form.swift:
- Show `host:port` (no space) on the left
- Show truncated working directory path on the right

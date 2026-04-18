---
title: "Android Streaming Markdown Renderer"
description: "Port the streaming markdown parser and renderer to Compose (code blocks, syntax highlighting, tables, inline formatting)."
created_at: 2026-03-28
tags: ["android", "ui", "markdown"]
icon: text.quote
build: 120
---
# Android Streaming Markdown Renderer {text.quote}


## Desired Outcome
Full markdown rendering matching iOS quality: headers, bold/italic/strikethrough, code blocks with syntax highlighting, tables, blockquotes, lists, links, inline code. Must handle streaming (text arriving chunk by chunk).

**Files (iOS reference):** StreamingMarkdownParser.swift (+6 extension files), StreamingMarkdownView.swift (+6 extension files)

---
title: "Conversation Recall Layer"
description: "Make conversations easier to recover later through summaries, name history, and surfaced outputs."
created_at: 2026-03-28
tags: ["memory", "ui"]
icon: text.magnifyingglass
build: 120
---


# Conversation Recall Layer
## Problem

Conversations are hard to recover once they drift out of view. Names change, large generated outputs get buried in scroll, and older conversations lose their shape.

## Scope

### 1. Conversation summaries
- generate concise summaries after longer conversations go idle
- store on `Conversation`
- surface in the conversation list and edit sheet
- feed into reflection and retrieval later

### 2. Name history
- preserve previous conversation names
- use them in search results only
- never clutter the main UI

### 3. Artifacts
- surface substantial generated outputs as trackable objects instead of leaving them buried in chat
- start with the simplest version that makes plans, documents, and code easy to revisit

## Rules

- Start with retrieval, not overbuilt artifact infrastructure.
- Keep the UI simple.
- Prefer local persistence and reuse of existing models or file preview flows.
- Search should explain why a conversation matched.

## Desired Outcome

A conversation can still be found later by what it was called, what it was about, or what it produced.

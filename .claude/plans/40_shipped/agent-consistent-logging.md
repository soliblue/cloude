---
title: "Agent Consistent Logging"
description: "Replace all remaining print() statements with the Log infrastructure across Mac agent services."
created_at: 2026-02-05
tags: ["agent"]
icon: text.alignleft
build: 31
---


# Agent Consistent Logging
Replace remaining `print` statements with `Log` across agent services. Logger infrastructure already exists — this is the cleanup pass to use it everywhere consistently.

**Files:** `WebSocketServer+HTTP.swift`, `Logger.swift`, and any other files still using `print()`

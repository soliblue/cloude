---
title: "Defer Environment Assignment to First Message"
description: "Deferred environment assignment to first message send so switching envs before chatting works correctly."
created_at: 2026-03-09
tags: ["env", "connection"]
icon: clock.arrow.2.circlepath
build: 82
---


# Defer Environment Assignment to First Message {clock.arrow.2.circlepath}
Don't bake in environmentId when creating a new chat. Instead, capture it when:
- User sends their first message
- User picks a working directory on an empty chat

This way switching envs before chatting works correctly.

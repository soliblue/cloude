---
title: "Scroll to Bottom on Message Send"
description: "Sending a message does not scroll the conversation to the bottom."
created_at: 2026-03-29
tags: ["ui"]
icon: arrow.down.to.line
build: 120
---


# Scroll to Bottom on Message Send
## Problem
When the user sends a message, the conversation view does not automatically scroll to show the new message and incoming response. The user has to manually scroll down.

## Desired Outcome
As soon as a message is sent, the view scrolls to the bottom so the new message and the streaming response are immediately visible.

## How to Test
1. Have a conversation with several messages so the view is scrollable
2. Scroll up into history so the bottom is not visible
3. Send a new message
4. The view should immediately scroll to the bottom showing the sent message and the incoming response

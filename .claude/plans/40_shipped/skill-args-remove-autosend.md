---
title: "Remove Skill Arg Forms"
description: "Removed custom form UI for skill arguments; selecting a skill now populates the input bar for freeform typing."
created_at: 2026-02-05
tags: ["skills", "input"]
icon: text.cursor
build: 31
---


# Remove Skill Arg Forms {text.cursor}
Currently skills with args show a custom form UI with input fields. Remove that — selecting a skill should just populate the input bar with the skill name. User types freeform context if needed, then sends. The AI figures out what to do from the skill prompt + user message.

- Skills with no args (like /clear, /compact) can auto-send immediately
- Everything else: no form, no structured inputs, just freeform text

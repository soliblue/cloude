---
title: "Apple Contacts Skill"
description: "Built Apple Contacts skill for searching and reading contacts via AppleScript."
created_at: 2026-02-14
tags: ["skill", "integration", "apple"]
icon: person.crop.rectangle.stack
build: 71
---


# Apple Contacts Skill
## Approach
AppleScript via `osascript`. Read-heavy — creating/editing contacts less common.

## Commands
- Search contacts by name
- Get contact details (phone, email, address, birthday)
- Create new contact
- List contacts in a group

## Use Cases
- "What's Mom's phone number?"
- "When is Hatem's birthday?"
- "Add this new contact: ..."
- Other skills: calendar can auto-lookup attendee emails, email can resolve "send to Adam"

**Files:** `.claude/skills/contacts/`, shell scripts with AppleScript

---
title: "Analysis Skills: Approval Gate + Plan Tickets"
description: "Added approval gate to /refactor, /reflect, and /skillsmith skills requiring user confirmation before implementing suggestions."
created_at: 2026-02-07
tags: ["skills"]
icon: checkmark.shield
build: 43
---


# Analysis Skills: Approval Gate + Plan Tickets
## What
Updated /refactor, /reflect, and /skillsmith to require Soli's approval before implementing any suggestions. When approved, a plan ticket must be created in plans/active/ or plans/testing/ before starting work.

## Why
These skills analyze and suggest changes, but shouldn't act autonomously. The approval gate ensures Soli controls what gets implemented, and the ticket requirement keeps the plans/ system as the single source of truth for all work.

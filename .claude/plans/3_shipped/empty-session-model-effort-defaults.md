---
title: "Empty Session Model Defaults"
description: "Persist model and effort choices selected from the empty session setup view."
created_at: 2026-05-10
updated_at: 2026-05-10
tags: ["settings", "ui"]
icon: slider.horizontal.3
---

# Empty Session Model Defaults

## Implementation

The empty session model and effort rows now write their selected values to `AppStorage`. Creating a new session reads those stored defaults and applies them to the new `Session` before it is inserted.

Selecting Auto for model or Default for effort clears the stored value, so future sessions return to daemon or Claude defaults.

## Verify

- Pick a non-default model and effort in an empty session.
- Create another empty session and confirm the same model and effort are preselected.
- Switch model back to Auto and effort back to Default, then create a new session and confirm the explicit defaults are cleared.

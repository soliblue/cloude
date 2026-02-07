# Model Selector (like Effort Selector)

## Problem
Model is currently hardcoded per-context (heartbeat uses Sonnet, conversations use nil/default). Users should be able to select the model the same way they select thinking effort — per-conversation default with per-message override.

## Design
Mirror the existing effort system exactly:

- **Per-conversation default**: Set in WindowEditSheet toolbar (like the brain icon for effort)
- **Per-message override**: Menu in GlobalInputBar send button (like effort menu)
- **Fallback**: `currentModel ?? conversation.defaultModel` → if nil, no `--model` flag (best model selected by CLI)

### Model Options
| Value | Display | Notes |
|-------|---------|-------|
| `nil` | "Auto" | No --model flag, CLI picks best |
| `"claude-opus-4-6"` | "Opus 4.6" | Most capable |
| `"claude-sonnet-4-5-20250929"` | "Sonnet 4.5" | Fast + capable |
| `"claude-haiku-4-5-20251001"` | "Haiku 4.5" | Fastest, cheapest |

## Changes

### Conversation.swift
- Add `ModelSelection` enum (like `EffortLevel`) with cases: `opus`, `sonnet`, `haiku`
- Each case maps to the full model ID string for the CLI `--model` flag
- Add `defaultModel: ModelSelection?` to `Conversation`

### GlobalInputBar.swift
- Add model menu alongside effort menu in send button options (lines 206-217)
- Add `@State var currentModel: ModelSelection?`
- Add `onModelChange` callback (like `onEffortChange`)

### WindowEditSheet.swift
- Add model picker in toolbar (like the brain icon for effort)

### MainChatView+Messaging.swift
- Pass `currentModel ?? conv.defaultModel` when sending chat
- Wire up `onModelChange` callback

### ConnectionManager+API.swift / ClientMessage
- Add `model: String?` to chat message payload

### Mac Agent (AppDelegate+MessageHandling)
- Read `model` from chat message, pass to RunnerManager

### ClaudeCodeRunner.swift
- Already supports `model` parameter (line 89-91) — no changes needed

### ConversationStore+Operations.swift
- Add `setDefaultModel()` (like `setDefaultEffort()`)

## Notes
- The CLI `--model` flag already works — this is purely UI + message plumbing
- "Auto" (nil) means the CLI picks the best available model, same as current behavior
- Model IDs may need updating when new models release — keep them in one place (the enum)

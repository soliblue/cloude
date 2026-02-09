# File-Based Conversation Storage

## Problem
iOS UserDefaults has a ~4MB limit. All conversations (with messages, base64 images, tool outputs) were serialized into a single UserDefaults key, exceeding this limit and causing `CFPreferences` errors.

## Solution
Moved conversation storage from UserDefaults to individual JSON files in the app's Documents directory:
- `Documents/conversations/{uuid}.json` — one file per conversation
- `Documents/heartbeat.json` — heartbeat conversation

## Changes
- **ConversationStore.swift**: `save()` and `load()` use files instead of UserDefaults. Includes migration from legacy UserDefaults data on first run.
- **ConversationStore+Operations.swift**: `mutate()` saves only the changed conversation (not all). `deleteConversation()` deletes the file.
- **HeartbeatStore.swift**: Same treatment — file-based with UserDefaults migration.

## Migration
On first launch after update, existing data is read from UserDefaults, written to files, then the UserDefaults key is removed. Seamless, no data loss.

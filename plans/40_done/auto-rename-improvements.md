# Auto-Rename Improvements

## Problem
- Auto-naming only fired on the 1st user message, then every 5th assistant message
- First rename had no conversation context (empty array), so names were often vague
- Names weren't descriptive enough to identify what a window is actually doing

## Changes
- **Trigger on 2nd message too**: After the 2nd assistant response, fire another rename with full conversation context (up to 10 messages). This catches the real topic after the initial back-and-forth.
- **Better context**: Pass up to 10 recent messages (300 chars each) with User/Assistant labels, instead of 4 messages with 200 chars
- **Better prompt**: Rewritten to emphasize descriptive, specific names ("Auth Bug Fix", "Dark Mode") over catchy/generic ones ("Spark", "Quick Fix"). Explicitly tells the model this is a chat window name the user glances at.
- **Every 5 still works**: The periodic rename every 5 assistant messages continues with the improved context.

## Files Changed
- `ConversationView.swift` — added `assistantCount == 2` trigger, richer context
- `AutocompleteService.swift` — rewrote naming prompt for specificity

## Build
- Needs TestFlight or Xcode run to test

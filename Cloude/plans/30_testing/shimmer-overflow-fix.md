# Shimmer Overflow Fix
<!-- build: 82 -->

Shimmer gradient on executing tool pills was overflowing beyond the pill bounds. Added `.clipShape(RoundedRectangle(cornerRadius: 8))` to contain it.

## Test
- Start a conversation and send a message that triggers tool calls
- Watch the shimmer animation on executing tool pills
- Verify the shimmer stays within the pill boundary and doesn't bleed outside

# Shimmer Overflow Fix

Shimmer gradient on executing tool pills overflows beyond the pill bounds. The `ShimmerOverlay` phase goes up to 1.5x width with no clip shape to contain it.

Fix: Add `.clipShape(RoundedRectangle(cornerRadius: 8))` to match the glass effect shape.

# Shimmer Overflow Fix {rectangle.dashed}
<!-- priority: 10 -->
<!-- tags: tool-pill, ui -->

> Fixed shimmer gradient overflowing tool pill bounds by adding a clip shape.

Shimmer gradient on executing tool pills overflows beyond the pill bounds. The `ShimmerOverlay` phase goes up to 1.5x width with no clip shape to contain it.

Fix: Add `.clipShape(RoundedRectangle(cornerRadius: 8))` to match the glass effect shape.

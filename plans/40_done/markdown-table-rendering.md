# Better Markdown Table Rendering
<!-- priority: 10 -->
<!-- tags: markdown, ui -->
<!-- build: 56 -->

Tables in markdown currently render with default styling — no visual structure. They should look like real tables with inner dividers and clean styling.

## Goals
- Inner borders/dividers between rows and columns (light gray)
- White background for cells
- No outer border (clean, modern look)
- Readable at mobile size

## Approach
- Custom table renderer in the markdown rendering pipeline
- Light gray horizontal rules between rows (`Color.gray.opacity(0.2)` or similar)
- Light gray vertical dividers between columns
- White cell background, no outer border/frame
- Proper text alignment and padding per cell

## Files
- `Cloude/Cloude/UI/StreamingMarkdownView.swift` or wherever markdown rendering lives
- May need a new `MarkdownTableView.swift` component

## Notes
- Keep it lightweight — no heavy grid frameworks
- Should handle variable column widths gracefully on small screens (horizontal scroll if needed)
- Header row could be slightly bolder or have a subtle background tint

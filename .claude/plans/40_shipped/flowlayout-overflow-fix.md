# FlowLayout Overflow Fix {rectangle.compress.vertical}
<!-- priority: 10 -->
<!-- tags: ui, widget -->
<!-- build: 82 -->

> Fixed FlowLayout measuring subviews without width constraint, causing text overflow.

## Problem
FlowLayout measured subviews with `.unspecified` (no width constraint), so long text segments in widgets like Error Correction overflowed the screen width.

## Solution
- Constrain subviews to remaining row width when measuring and placing
- Added `.fixedSize(horizontal: false, vertical: true)` to ErrorCorrection text segments

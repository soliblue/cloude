# Compact Question Options

## Status: Testing

## Summary
Make `cloude ask` question option buttons significantly smaller — they were taking too much vertical space in the chat.

## Changes
- **QuestionView.swift**: Reduced all sizing across the board
  - Option row: icon 20→16, label 15→13, desc 13→11, padding 14h/12v→10h/8v, spacing 8→4
  - Question card: text `.subheadline`→`.footnote`, spacing 10→8
  - Container: padding 16→12, spacing 16→12, corner radius 16→14
  - Buttons: text `.subheadline`→`.footnote`, submit padding shrunk
  - Text field: font 14→13, padding 10→8, line limit 4→3

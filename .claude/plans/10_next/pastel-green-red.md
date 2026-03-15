# Pastel Green & Red

## Problem
System `.green` and `.red` are too saturated and clash with the warm orange accent (rgb 0.8/0.447/0.341). Need muted/pastel variants that feel cohesive.

## Proposal
Add `Color.pastelGreen` and `Color.pastelRed` to Colors.swift. Warm-toned pastels that sit well next to the orange.

### Candidates
| Name | Hex | RGB | Notes |
|------|-----|-----|-------|
| Sage Green | #7BAF7B | 123/175/123 | Muted, earthy |
| Moss Green | #8DB580 | 141/181/128 | Warmer, desaturated |
| Dusty Green | #82B28A | 130/178/138 | Slightly cooler |
| Soft Coral | #C27B6E | 194/123/110 | Warm red, close to accent family |
| Dusty Rose | #C4807A | 196/128/122 | Muted, warm |
| Muted Brick | #B87070 | 184/112/112 | Darker, more serious |

### Current pick: Moss Green + Dusty Rose
- Both warm-toned to match the orange accent
- Muted enough to not compete with accent for attention
- Still clearly readable as "added" and "removed"

## Where to apply
- Git diff stats (+N / -N) in file rows and header
- Git status badge colors (A = green, D = red)
- "staged" label color
- "changed" label (currently orange, keep as-is)
- Anywhere else `.green` or `.red` is used for success/danger semantics

## Open questions
- Should these be theme-aware or fixed across all themes?
- Do they need light mode variants? (app is dark-only currently)

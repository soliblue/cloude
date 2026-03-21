# Secondary Accent Color {paintpalette}
<!-- priority: 5 -->
<!-- tags: ui, settings -->

> Orange accent is overloaded for both active/selected and connected/status states; introduce a secondary color to distinguish them.

## Problem
Orange accent color is overloaded - used for active tabs, connected environments, power button, buttons. No visual distinction between "selected/active" and "on/connected."

## Proposal
Introduce a secondary accent color to differentiate roles:
- **Orange** = active/selected/interactive (tabs, buttons, primary actions)
- **Secondary** = connected/alive/status (env icons, connection state)

## Explored Palettes

### Reference points
- **Steel Blue** #6A9FBF - cooler, more blue
- **Soft Indigo** #7B8EC2 - warmer, more purple

### Candidates (between the two)
| Name | Hex | Notes |
|------|-----|-------|
| Slate Blue | #7297C4 | Leans slightly more blue |
| Dusty Blue | #7093B8 | More muted/neutral |
| Periwinkle Steel | #7A96C0 | Slightly more blue, good balance |
| Cadet Blue | #6D8FB5 | More muted/neutral |
| Muted Denim | #7590B0 | Most muted of the set |
| Warm Periwinkle | #8098C2 | Most warmth, closest to indigo |

### Current favorite: Slate Blue (#7297C4)

## Where to apply
- Environment icons in toolbar (connected state)
- Environment icon in window header (connected state)
- Power button connected state
- Any future "status" indicators

## Open questions
- Does it work well across all 23 themes?
- Should it be theme-aware (different shade per theme) or fixed?

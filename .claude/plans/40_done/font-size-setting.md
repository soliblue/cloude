# Font Size Setting {textformat.size}
<!-- priority: 5 -->
<!-- build: 120 -->
<!-- tags: settings, ui -->

> Add a font size control in settings with + and - buttons, 4 steps total.

## Problem
There is no way to adjust the font size in the app. Users with different preferences or accessibility needs have no control over text size.

## Desired Outcome
A row in the settings sheet with a label, a `-` button on the left and a `+` button on the right. The default is the smallest size (step 0). Each `+` tap increases font size by 1 point across the app. Maximum is 3 steps above default. The `-` button is disabled at step 0, the `+` button is disabled at step 3. The setting persists across launches.

## How to Test
1. Open settings
2. Find the font size row
3. Tap `+` — text in the app should visibly increase
4. Tap `+` two more times — should reach max, button should disable
5. Tap `-` — text should decrease, button re-enables
6. Close and reopen the app — font size should be remembered
7. At step 0, the `-` button should be disabled

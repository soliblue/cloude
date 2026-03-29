# Theme and Debugger Polish {paintbrush}
<!-- priority: 6 -->
<!-- tags: ui, tooling -->

> Tighten a few UI inconsistencies and route VS Code run output into the debug console.

## Problem
A few interface surfaces were still bypassing existing design tokens and theme helpers, conversation labels needed stronger hierarchy, message bubbles did not reliably rerender when font size changed, and VS Code launches were using the integrated terminal instead of the debug console.

## Desired Outcome
Toolbar and window conversation labels have the intended emphasis, obvious hardcoded settings sizes are replaced with existing tokens, theme picker colors go through shared helpers, message bubbles refresh immediately after font size changes, and VS Code iOS launch output appears in the Debug Console.

## How to Test
1. Open settings and change font size while a conversation with existing messages is visible
2. Confirm user and assistant message bubbles update their text sizing immediately
3. Verify the top conversation title and window conversation labels render semibold
4. Open the theme picker and confirm it still reflects the active theme correctly
5. Launch `iOS Simulator` or `Connected iPhone` from VS Code and confirm output lands in Debug Console instead of the integrated terminal

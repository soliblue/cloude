# Header Tab Buttons

Move conversation info to nav toolbar center, replace window header title pill with Chat/Files/Git tab icon buttons.

## Changes
- CloudeApp.swift: Added `.principal` toolbar item with conversation name/folder/cost (no SF symbol)
- MainChatView+Windows.swift: Replaced title pill with 3 tab icon buttons (WindowType.allCases)
- MainChatView.swift: Added `.editActiveWindow` notification listener
- WidgetView+Shared.swift: Added `.editActiveWindow` notification name

## Status
Implemented, awaiting deploy and testing.

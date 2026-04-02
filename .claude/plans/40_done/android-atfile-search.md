# Android @file Search Suggestions {doc.text.magnifyingglass}
<!-- priority: 12 -->
<!-- tags: android, input, files -->

> Type @filename in the input bar to search and reference files from the server.

## Desired Outcome
When the user types @ followed by text, send a file search query to the server and show matching file paths as tappable suggestion pills. Tapping a pill inserts the full file path into the input.

## How iOS Does It
- Detects @ prefix in input text (after last space or at start)
- Sends file_search client message with the query to the server
- Server returns file_search_results with matching file paths
- Results shown as horizontal scrollable pills below the input
- Tapping a pill inserts the path and dismisses suggestions

## Implementation
- Detect @query pattern in InputBar.kt (similar to / slash detection)
- Send ClientMessage.FileSearch(query, workingDirectory) when query changes (debounced)
- Listen for ServerMessage.FileSearchResults in ChatViewModel
- Expose results as StateFlow, collect in ChatScreen and pass to InputBar
- Show file path pills in a horizontal scroll row (reuse pill pattern from slash commands)
- Tapping inserts the full path at cursor position

## Files
- InputBar.kt - @query detection, pill display
- ChatViewModel.kt - file search state
- ClientMessage.kt - FileSearch message (check if exists)
- ChatScreen.kt - wire results to InputBar

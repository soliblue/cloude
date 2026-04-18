# Long Markdown Streaming

Verify the app streams and renders a long single-response markdown answer cleanly.

1. Send `prompts/long-markdown-output.txt`.
2. Wait for the response to finish.

## Assertions

- all 8 sections render
- headings, bullet lists, and the short table render correctly
- no stuck live bubble after completion
- render count remains stable after completion

# Word Wrap in File Preview {text.word.spacing}
<!-- priority: 10 -->
<!-- tags: file-preview -->
<!-- build: 56 -->

> Enabled word wrapping for code/text files in file preview by removing horizontal scroll wrapper.

Enable word wrapping for code/text files in the file preview, like most IDEs default to.

## Change

Removed the outer `ScrollView(.horizontal)` from `FilePathPreviewView+Content.swift` so long lines wrap to the screen width instead of requiring horizontal scrolling. Vertical scrolling remains for navigating long files.

## Files
- `Cloude/Cloude/UI/FilePathPreviewView+Content.swift` — removed horizontal scroll wrapper around text content

## Test
- Open a file with long lines from an inline path pill
- Confirm lines wrap to screen width (no horizontal scrolling)
- Confirm syntax highlighting still works on wrapped lines
- Confirm vertical scrolling works normally

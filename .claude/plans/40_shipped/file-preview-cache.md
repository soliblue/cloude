# File Preview Cache {internaldrive}
<!-- priority: 10 -->
<!-- tags: file-preview -->

> Added LRU cache (15 entries) for decoded file data so reopening files is instant.

LRU cache (max 15 entries) for decoded file data on iOS. Reopening a previously viewed file is instant — no round-trip to the Mac agent.

Cache sits on `ConnectionManager.fileCache`, populated when `handleFileContent` fires (covers both single-message and chunked files). Both `FilePathPreviewView` (chat pills) and `FilePreviewView` (file browser) check cache before requesting.

**Files:** `ConnectionManager.swift` (FileCache struct), `ConnectionManager+API.swift`, `FilePathPreviewView+Content.swift`, `FilePreviewView+Loading.swift`

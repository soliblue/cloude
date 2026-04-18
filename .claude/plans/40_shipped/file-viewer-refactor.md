# File Viewer Architecture Refactor {arrow.triangle.2.circlepath}
<!-- priority: 10 -->
<!-- tags: file-preview, refactor -->
<!-- build: 56 -->

> Replaced scattered file type detection with centralized FileContentType enum and per-type viewer files.

Replaced scattered file type detection (`isMarkdown`, `isJSON`, `isCode`, `isMarkup`, `isImage`, `isText` computed properties + `highlightLanguage` dictionary) with a single `FileContentType` enum. Centralizes extension-to-type mapping, highlight language, `hasRichView` and `isTextBased` flags. Content rendering dispatches through `richContentView()` switch instead of growing if/else chain. Each rich viewer is its own file: `JSONTreeView`, `CSVTableView`, `HTMLRenderedView`, `YAMLParser`. Adding new rich formats = add enum case + switch branch + viewer file.

# File Viewer Architecture Refactor
<!-- priority: 10 -->
<!-- tags: files, refactor -->
<!-- build: 56 -->

Replaced scattered file type detection (`isMarkdown`, `isJSON`, `isCode`, `isMarkup`, `isImage`, `isText` computed properties + `highlightLanguage` dictionary) with a single `FileContentType` enum. Centralizes extension-to-type mapping, highlight language, `hasRichView` and `isTextBased` flags. Content rendering dispatches through `richContentView()` switch instead of growing if/else chain. Each rich viewer is its own file: `JSONTreeView`, `CSVTableView`, `HTMLRenderedView`, `YAMLParser`. Adding new rich formats = add enum case + switch branch + viewer file.

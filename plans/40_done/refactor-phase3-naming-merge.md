# Refactor Phase 3: Parent+Feature Naming & FilePreview Merge

## Status: Testing

## Changes

### Deleted 6 dead code files
- `PulsingBorder.swift` — zero references
- `HeartbeatButton.swift` — replaced by inline impl in MainChatView+PageIndicator
- `NewFolderSheet.swift` — never instantiated
- `HeartbeatSheet.swift` — zero references
- `ToolCallRow.swift` — zero instantiations
- `HeartbeatStore.swift` — zero references (Models)

### Merged FilePreviewView + FilePathPreviewView
- Combined into single `FilePreviewView` with dual initializers:
  - `init(file: FileEntry, connection:)` — from FileBrowserView
  - `init(path: String, connection:)` — from CloudeApp
- Merged features: syntax highlighting, rendered views (markdown/JSON/YAML/CSV/HTML), directory browsing, source toggle, thumbnail support
- Deleted `FilePathPreviewView.swift` and `FilePathPreviewView+Content.swift`
- Removed unused `TextPreview` and `BinaryPreview` from +Previews

### Renamed 27 orphan components to Parent+Feature pattern
| Old | New |
|-----|-----|
| AudioWaveformView.swift | GlobalInputBar+AudioWaveform.swift |
| InteractiveBarChart.swift | UsageStatsSheet+BarChart.swift |
| WindowEditForm.swift | WindowEditSheet+Form.swift |
| EmptyConversationView.swift | ConversationView+EmptyState.swift |
| HeartbeatChatView.swift | MainChatView+HeartbeatChat.swift |
| InlineTextView.swift | StreamingMarkdownView+InlineText.swift |
| ReadingProgressView.swift | ConversationView+ReadingProgress.swift |
| SyntaxHighlighter.swift | MarkdownText+SyntaxHighlighter.swift |
| QuestionView.swift | ConversationView+Question.swift |
| CSVTableView.swift | FilePreviewView+CSVTable.swift |
| JSONTreeView.swift | FilePreviewView+JSONTree.swift |
| HTMLRenderedView.swift | FilePreviewView+HTMLRendered.swift |
| FileContentType.swift | FilePreviewView+ContentType.swift |
| FileViewerBreadcrumb.swift | FilePreviewView+Breadcrumb.swift |
| CostBanner.swift | ConversationView+CostBanner.swift |
| ConversationInfoLabel.swift | MainChatView+ConversationInfo.swift |
| ConversationSearchSheet.swift | MainChatView+SearchSheet.swift |
| ConnectionStatusLogo.swift | CloudeApp+StatusLogo.swift |
| LockScreenView.swift | CloudeApp+LockScreen.swift |
| MemoriesSheet.swift | CloudeApp+MemoriesSheet.swift |
| PlansSheet.swift | CloudeApp+PlansSheet.swift |
| SymbolPickerSheet.swift | WindowEditSheet+SymbolPicker.swift |
| FileDiffSheet.swift | FilePreviewView+DiffSheet.swift |
| TeamBannerView.swift | ConversationView+TeamBanner.swift |
| TeamOrbsOverlay.swift | ConversationView+TeamOrbs.swift |
| TeamOrbsOverlay+Detail.swift | ConversationView+TeamOrbs+Detail.swift |
| BashCommandIcons.swift | ToolCallLabel+BashIcons.swift |
| ClipboardHelper.swift | MessageBubble+Clipboard.swift |
| MemoryParser.swift | CloudeApp+MemoryParser.swift |
| YAMLParser.swift | FilePreviewView+YAMLParser.swift |

### Kept standalone (multi-parent)
- `InlineToolPill.swift` — MessageBubble+Components, StreamingMarkdownView
- `ToolCallLabel.swift` — InlineToolPill, ToolDetailSheet, ToolDetailSheet+Content
- `ToolDetailSheet.swift` — InlineToolPill (sheet presentation)
- `PillStyles.swift` — MessageBubble+SlashCommand, GlobalInputBar+Components
- `FileIconUtilities.swift` — ToolDetailSheet+Content, GlobalInputBar+Components, StreamingMarkdownView+InlineText
- `UsageStatsSheet.swift` — MainChatView, SettingsView
- `SlashCommand.swift` — GlobalInputBar, GlobalInputBar+Components, MessageBubble+SlashCommand
- `ImageEncoder.swift` — MainChatView+Messaging, HeartbeatSheet
- `StreamingBlock.swift` — StreamingMarkdownParser, StreamingMarkdownView
- `FolderPickerView.swift` — WindowEditSheet+Form (reusable picker)

### Updated CLAUDE.md UI Component Map
- All renamed files reflected in component map tables
- Removed HeartbeatSheet entry (deleted)

## Test
- Build succeeds (verified with xcodebuild)
- File preview from FileBrowserView still works (FileEntry path)
- File preview from path links still works (String path)
- Syntax highlighting, rendered views, directory browsing all functional
- Source/rendered toggle in toolbar works

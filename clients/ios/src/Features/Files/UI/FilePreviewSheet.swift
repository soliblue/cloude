import QuickLook
import SwiftUI

struct FilePreviewSheet: View {
    let session: Session
    let node: FileNodeDTO
    var isPushed: Bool = false
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StorageKey.wrapCodeLines) private var wrapCodeLines = false
    @State private var store = FilePreviewStore()
    @State private var fullPreview: URL?
    @State private var showSource = false

    var body: some View {
        if isPushed {
            content
        } else {
            NavigationStack { content }
        }
    }

    private var content: some View {
        let type = FilePreviewContentType.detect(for: node)
        let showingCode = showSource || type.isCode
        let actionPlacement: ToolbarItemPlacement = isPushed ? .topBarTrailing : .topBarLeading
        return Group {
            if let resource = store.resource {
                VStack(spacing: 0) {
                    if resource.isCached || resource.isTruncated {
                        HStack {
                            Text(resource.isTruncated ? "Large file preview" : "Saved on this iPhone")
                            Spacer()
                            Button("Open full file") { fullPreview = resource.url }
                        }
                        .appFont(size: ThemeTokens.Text.s)
                        .padding(ThemeTokens.Spacing.m)
                        .background(theme.palette.surface)
                    }
                    if case .html = type, !showSource, !resource.isTruncated {
                        Text("Offline preview. External resources are blocked.")
                            .appFont(size: ThemeTokens.Text.s)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(ThemeTokens.Spacing.m)
                            .background(theme.palette.surface)
                    }
                    if let data = resource.data, showSource && type.hasRenderedView {
                        FilePreviewCode(data: data, language: type.sourceLanguage, wrap: wrapCodeLines)
                    } else {
                        FilePreviewSheetContent(node: node, type: type, resource: resource, wrap: wrapCodeLines)
                            .id(resource.id)
                    }
                }
            } else if store.failed {
                ContentUnavailableView {
                    Label("Unable to load file", systemImage: "doc.badge.ellipsis")
                } description: {
                    Text("Check your connection and that this file still exists.")
                } actions: {
                    Button("Try again") { store.attempt += 1 }
                }
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.palette.background)
        .navigationTitle(node.name)
        .navigationBarTitleDisplayMode(.inline)
        .themedNavChrome()
        .quickLookPreview($fullPreview)
        .toolbar {
            ToolbarItem(placement: actionPlacement) {
                if type.hasRenderedView {
                    Button {
                        showSource.toggle()
                    } label: {
                        Image(
                            systemName: showSource
                                ? "doc.richtext" : "chevron.left.forwardslash.chevron.right"
                        )
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        .frame(width: ThemeTokens.Size.m, height: ThemeTokens.Size.m)
                    }
                    .accessibilityLabel(showSource ? "Show rendered file" : "Show source")
                }
            }
            ToolbarItem(placement: actionPlacement) {
                if showingCode {
                    Button {
                        wrapCodeLines.toggle()
                    } label: {
                        Image(
                            systemName: wrapCodeLines
                                ? "arrow.left.and.right.text.vertical" : "text.word.spacing"
                        )
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        .frame(width: ThemeTokens.Size.m, height: ThemeTokens.Size.m)
                    }
                    .accessibilityLabel(wrapCodeLines ? "Disable line wrapping" : "Wrap long lines")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let resource = store.resource {
                    ShareLink(item: resource.url)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let resource = store.resource {
                    Button("Open full file", systemImage: "arrow.up.left.and.arrow.down.right") {
                        fullPreview = resource.url
                    }
                }
            }
            if !isPushed {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                    }
                    .accessibilityLabel("Close file")
                }
            }
        }
        .task(id: "\(session.connectionKey)|\(node.path)|\(store.attempt)") {
            fullPreview = nil
            store.failed = false
            store.resource = nil
            let cached = await FilePreviewService.cached(session: session, node: node)
            if !Task.isCancelled { store.resource = cached }
            let resource = await FilePreviewService.load(session: session, node: node)
            if !Task.isCancelled {
                store.resource = resource
                store.failed = resource == nil
            }
        }
    }
}

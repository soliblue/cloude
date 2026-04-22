import SwiftUI

struct FilePreviewSheet: View {
    let session: Session
    let node: FileNodeDTO
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StorageKey.wrapCodeLines) private var wrapCodeLines = false
    @State private var data: Data?
    @State private var failed = false
    @State private var showSource = false

    var body: some View {
        let type = FilePreviewContentType.detect(for: node)
        let showingCode = showSource || type.isCode
        NavigationStack {
            Group {
                if let data {
                    if showSource && type.hasRenderedView {
                        FilePreviewCode(
                            data: data, language: type.sourceLanguage, wrap: wrapCodeLines)
                    } else {
                        FilePreviewSheetContent(node: node, type: type, data: data, wrap: wrapCodeLines)
                    }
                } else if failed {
                    Text("Unable to load file")
                        .appFont(size: ThemeTokens.Text.m)
                        .foregroundColor(.secondary)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(theme.palette.background)
            .navigationTitle(node.name)
            .themedNavChrome()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
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
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
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
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                    }
                }
            }
        }
        .task {
            if let endpoint = session.endpoint {
                let result = await FilesService.read(endpoint: endpoint, session: session, path: node.path)
                if let result {
                    data = result
                } else {
                    failed = true
                }
            } else {
                failed = true
            }
        }
    }

}

import SwiftUI
import CloudeShared
import HighlightSwift

extension FilePathPreviewView {
    @ViewBuilder
    var content: some View {
        if isLoading {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading...")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if directoryEntries != nil {
            FileBrowserView(connection: connection, rootPath: path)
        } else if let error = errorMessage {
            ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
        } else if let data = fileData {
            fileContent(data)
        }
    }

    @ViewBuilder
    func fileContent(_ data: Data) -> some View {
        if case .image = contentType, let image = UIImage(data: data) {
            ScrollView {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
            }
        } else if contentType.isTextBased, let text = String(data: data, encoding: .utf8) {
            if contentType.hasRenderedView && !showSource, let rendered = renderedView(text: text, data: data) {
                rendered
            } else {
                sourceTextView(text)
            }
        } else {
            binaryPlaceholder(data)
        }
    }

    @ViewBuilder
    private func renderedView(text: String, data: Data) -> (some View)? {
        switch contentType {
        case .markdown:
            scrollingContent { StreamingMarkdownView(text: text) }
        case .yaml:
            if let jsonValue = YAMLParser.parse(text) {
                scrollingContent { JSONTreeView(value: jsonValue, label: fileName) }
            }
        case .csv:
            scrollingContent { CSVTableView(text: text, delimiter: fileExtension == "tsv" ? "\t" : ",") }
        case .html:
            HTMLRenderedView(html: text)
        case .json:
            if let jsonValue = try? JSONSerialization.jsonObject(with: data) {
                scrollingContent { JSONTreeView(value: jsonValue, label: fileName) }
            }
        default:
            nil as EmptyView?
        }
    }

    @ViewBuilder
    private func scrollingContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.vertical) {
            content()
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func sourceTextView(_ text: String) -> some View {
        ScrollView(.vertical) {
            if let highlighted = highlightedCode {
                Text(highlighted)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(text)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func binaryPlaceholder(_ data: Data) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "doc")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text(fileName)
                .font(.headline)
            Text("\(data.count.formatted(.byteCount(style: .file)))")
                .foregroundColor(.secondary)
        }
    }

    func loadFile() {
        isLoading = true
        connection.getFile(path: path)

        connection.onFileContent = { responsePath, data, mime, _, _ in
            guard responsePath == path else { return }
            mimeType = mime

            if let decoded = Data(base64Encoded: data) {
                fileData = decoded
                if contentType.highlightLanguage != nil, let text = String(data: decoded, encoding: .utf8) {
                    highlightCode(text)
                } else {
                    isLoading = false
                }
            } else {
                errorMessage = "Failed to decode file"
                isLoading = false
            }
        }

        connection.onDirectoryListing = { responsePath, entries in
            guard responsePath == path else { return }
            directoryEntries = entries
            isLoading = false
        }
    }

    func highlightCode(_ code: String) {
        Task {
            let highlight = Highlight()
            let colors: HighlightColors = colorScheme == .dark ? .dark(.xcode) : .light(.xcode)
            do {
                let result: AttributedString
                if let lang = contentType.highlightLanguage {
                    result = try await highlight.attributedText(code, language: lang, colors: colors)
                } else {
                    result = try await highlight.attributedText(code, colors: colors)
                }
                await MainActor.run {
                    highlightedCode = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

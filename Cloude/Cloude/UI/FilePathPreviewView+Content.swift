import SwiftUI
import CloudeShared
import HighlightSwift

extension FilePathPreviewView {
    var isImage: Bool {
        ["png", "jpg", "jpeg", "gif", "webp", "heic", "svg"].contains(fileExtension)
    }

    var isCode: Bool {
        ["swift", "py", "js", "ts", "jsx", "tsx", "go", "rs", "rb", "java", "kt", "c", "cpp", "h", "m", "cs", "php", "sh", "bash", "zsh"].contains(fileExtension)
    }

    var isMarkup: Bool {
        ["html", "css", "scss", "xml", "json", "yaml", "yml", "toml", "plist", "md"].contains(fileExtension)
    }

    var isText: Bool {
        ["txt", "log", "rtf"].contains(fileExtension) || isCode || isMarkup
    }

    var highlightLanguage: String? {
        let langMap: [String: String] = [
            "swift": "swift", "py": "python", "js": "javascript", "ts": "typescript",
            "jsx": "javascript", "tsx": "typescript", "go": "go", "rs": "rust",
            "rb": "ruby", "java": "java", "kt": "kotlin", "c": "c", "cpp": "cpp",
            "h": "c", "m": "objectivec", "cs": "csharp", "php": "php",
            "sh": "bash", "bash": "bash", "zsh": "bash",
            "html": "html", "css": "css", "scss": "scss", "xml": "xml",
            "json": "json", "yaml": "yaml", "yml": "yaml", "toml": "ini",
            "plist": "xml", "md": "markdown"
        ]
        return langMap[fileExtension]
    }

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
        if isImage, let image = UIImage(data: data) {
            ScrollView {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
            }
        } else if isText, let text = String(data: data, encoding: .utf8) {
            ScrollView(.vertical) {
                if let highlighted = highlightedCode {
                    Text(highlighted)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(text)
                        .font(.system(size: 13, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Color(.systemBackground))
        } else {
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
    }

    func loadFile() {
        isLoading = true
        connection.getFile(path: path)

        connection.onFileContent = { responsePath, data, mime, _, _ in
            guard responsePath == path else { return }
            mimeType = mime

            if let decoded = Data(base64Encoded: data) {
                fileData = decoded
                if isCode || isMarkup, let text = String(data: decoded, encoding: .utf8) {
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
                if let lang = highlightLanguage {
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

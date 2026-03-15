import SwiftUI
import AVKit
import Combine
import CloudeShared
import HighlightSwift

extension FilePreviewView {
    @ViewBuilder
    var content: some View {
        if isLoading {
            VStack(spacing: 16) {
                if let progress = currentProgress {
                    VStack(spacing: 8) {
                        ProgressView(value: Double(progress.current + 1), total: Double(progress.total))
                            .progressViewStyle(.linear)
                            .frame(width: 200)
                        Text("\(progress.current + 1) of \(progress.total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if directoryEntries != nil {
            FileBrowserView(connection: connection, rootPath: path, environmentId: environmentId)
        } else if let error = errorMessage {
            ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
        } else if showDiff {
            diffContent
        } else if let data = fileData {
            fileContent(data)
        }
    }

    @ViewBuilder
    var diffContent: some View {
        if isDiffLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let diff = diffText, !diff.isEmpty {
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                DiffTextView(diff: diff, language: SyntaxHighlighter.languageForPath(fileName))
                    .padding()
            }
            .background(Color.oceanSystemBackground)
        } else {
            ContentUnavailableView(
                "No Changes",
                systemImage: "checkmark.circle",
                description: Text("No unstaged changes for this file")
            )
        }
    }

    @ViewBuilder
    func fileContent(_ data: Data) -> some View {
        if case .gif = contentType {
            GIFPreview(data: data)
        } else if case .image = contentType, let image = UIImage(data: data) {
            VStack {
                ImagePreview(image: image)
                if isThumbnail {
                    thumbnailBanner
                }
            }
        } else if case .video = contentType {
            VideoPreview(data: data)
        } else if case .audio = contentType {
            AudioPreview(data: data, fileName: fileName)
        } else if case .pdf = contentType {
            PDFPreview(data: data)
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
            ScrollView(.vertical) {
                CSVTableView(text: text, delimiter: fileExtension == "tsv" ? "\t" : ",")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.oceanSystemBackground)
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
        .background(Color.oceanSystemBackground)
    }

    @ViewBuilder
    private func sourceTextView(_ text: String) -> some View {
        let lines = text.components(separatedBy: "\n")
        ScrollView(wrapCodeLines ? [.vertical] : [.vertical, .horizontal]) {
            HStack(alignment: .top, spacing: 0) {
                if showLineNumbers && lines.count > 1 && !wrapCodeLines {
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(1...lines.count, id: \.self) { num in
                            Text("\(num)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .frame(height: 13.5)
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                    .padding(.top, 16)

                    Divider()
                }

                if let highlighted = highlightedCode {
                    Text(highlighted)
                        .font(.system(size: 10, design: .monospaced))
                        .lineSpacing(1.5)
                        .fixedSize(horizontal: !wrapCodeLines, vertical: false)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: wrapCodeLines ? .infinity : nil, alignment: .leading)
                } else {
                    Text(text)
                        .font(.system(size: 10, design: .monospaced))
                        .lineSpacing(1.5)
                        .fixedSize(horizontal: !wrapCodeLines, vertical: false)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: wrapCodeLines ? .infinity : nil, alignment: .leading)
                }
            }
        }
        .background(Color.oceanSystemBackground)
    }

    @ViewBuilder
    private func binaryPlaceholder(_ data: Data) -> some View {
        VStack(spacing: 16) {
            Image(systemName: fileEntry?.icon ?? "doc")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text(fileName)
                .font(.headline)
            Text("\(data.count.formatted(.byteCount(style: .file)))")
                .foregroundColor(.secondary)
            if let entry = fileEntry {
                ShareLink(item: data, preview: SharePreview(entry.name)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

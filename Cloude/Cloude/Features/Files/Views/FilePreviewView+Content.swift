import SwiftUI
import AVKit
import Combine
import CloudeShared
import HighlightSwift

extension FilePreviewView {
    @ViewBuilder
    var content: some View {
        switch loadPhase {
        case .loading:
            VStack(spacing: DS.Spacing.l) {
                if let progress = currentProgress {
                    VStack(spacing: DS.Spacing.s) {
                        ProgressView(value: Double(progress.current + 1), total: Double(progress.total))
                            .progressViewStyle(.linear)
                            .frame(width: DS.Size.xxl)
                        Text("\(progress.current + 1) of \(progress.total)")
                            .font(.system(size: DS.Text.s))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView()
                        .scaleEffect(DS.Scale.l)
                    Text("Loading...")
                        .font(.system(size: DS.Text.m))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .directory:
            FileBrowserView(environmentStore: environmentStore, rootPath: path, environmentId: environmentId)
        case .error(let message):
            ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(message))
        case .loaded, .thumbnail:
            if diff != .hidden {
                diffContent
            } else if let data = fileData {
                fileContent(data)
            }
        }
    }

    @ViewBuilder
    var diffContent: some View {
        switch diff {
        case .loading:
            ProgressView()
        case .loaded(let text) where !text.isEmpty:
            DiffScrollView(diff: text, fileName: fileName)
                .background(Color.themeBackground)
        case .loaded:
            ContentUnavailableView(
                "No Changes",
                systemImage: "checkmark.circle",
                description: Text("No unstaged changes for this file")
            )
        case .hidden:
            EmptyView()
        }
    }

    @ViewBuilder
    func fileContent(_ data: Data) -> some View {
        if case .gif = contentType {
            GIFPreview(data: data)
        } else if case .image = contentType, let image = UIImage(data: data) {
            VStack {
                ImagePreview(image: image)
                if case .thumbnail(let fullSize, let isLoadingFull) = loadPhase {
                    thumbnailBanner(fullSize: fullSize, isLoadingFull: isLoadingFull)
                }
            }
        } else if case .video = contentType {
            VideoPreview(data: data)
        } else if case .audio = contentType {
            AudioPreview(data: data, fileName: fileName)
        } else if case .pdf = contentType {
            PDFPreview(data: data)
        } else if contentType.isTextBased, let text = String(data: data, encoding: .utf8) {
            if contentType.hasRenderedView && viewMode == .rendered, let rendered = renderedView(text: text, data: data) {
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
            scrollingContent { FilePreviewMarkdownView(text: text) }
        case .yaml:
            if let jsonValue = YAMLParser.parse(text) {
                scrollingContent { JSONTreeView(value: jsonValue, label: fileName) }
            }
        case .csv:
            ScrollView(.vertical, showsIndicators: false) {
                CSVTableView(text: text, delimiter: fileExtension == "tsv" ? "\t" : ",")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.themeBackground)
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
        ScrollView(.vertical, showsIndicators: false) {
            content()
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.themeBackground)
    }
}

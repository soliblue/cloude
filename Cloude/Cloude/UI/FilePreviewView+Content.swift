// FilePreviewView+Content.swift

import SwiftUI
import AVKit
import Combine
import CloudeShared
import HighlightSwift

extension FilePreviewView {
    @ViewBuilder
    var content: some View {
        if isLoading {
            VStack(spacing: DS.Spacing.l) {
                if let progress = currentProgress {
                    VStack(spacing: DS.Spacing.s) {
                        ProgressView(value: Double(progress.current + 1), total: Double(progress.total))
                            .progressViewStyle(.linear)
                            .frame(width: 200)
                        Text("\(progress.current + 1) of \(progress.total)")
                            .font(.system(size: DS.Text.s))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .font(.system(size: DS.Text.m))
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
        } else if let diff = diffText, !diff.isEmpty {
            DiffScrollView(diff: diff, fileName: fileName)
                .background(Color.themeBackground)
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

// FilePreviewView+SourceView.swift

import SwiftUI
import CloudeShared

extension FilePreviewView {
    @ViewBuilder
    func sourceTextView(_ text: String) -> some View {
        let lines = text.components(separatedBy: "\n")
        ScrollView(wrapCodeLines ? [.vertical] : [.vertical, .horizontal]) {
            HStack(alignment: .top, spacing: 0) {
                if showLineNumbers && lines.count > 1 && !wrapCodeLines {
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(1...lines.count, id: \.self) { num in
                            Text("\(num)")
                                .font(.caption2.monospaced())
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
                        .font(.caption2.monospaced())
                        .lineSpacing(1.5)
                        .fixedSize(horizontal: !wrapCodeLines, vertical: false)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: wrapCodeLines ? .infinity : nil, alignment: .leading)
                } else {
                    Text(text)
                        .font(.caption2.monospaced())
                        .lineSpacing(1.5)
                        .fixedSize(horizontal: !wrapCodeLines, vertical: false)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: wrapCodeLines ? .infinity : nil, alignment: .leading)
                }
            }
        }
        .background(Color.themeSystemBackground)
    }

    @ViewBuilder
    func binaryPlaceholder(_ data: Data) -> some View {
        VStack(spacing: 16) {
            Image(systemName: fileEntry?.icon ?? "doc")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(fileName)
                .font(.subheadline.weight(.semibold))
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

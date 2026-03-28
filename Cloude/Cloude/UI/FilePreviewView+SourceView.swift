// FilePreviewView+SourceView.swift

import SwiftUI
import CloudeShared

extension FilePreviewView {
    @ViewBuilder
    func sourceTextView(_ text: String) -> some View {
        ScrollView(wrapCodeLines ? [.vertical] : [.vertical, .horizontal], showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                if let highlighted = highlightedCode {
                    Text(highlighted)
                        .font(.system(size: DS.Text.s, design: .monospaced))
                        .lineSpacing(1.5)
                        .fixedSize(horizontal: !wrapCodeLines, vertical: false)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: wrapCodeLines ? .infinity : nil, alignment: .leading)
                } else {
                    Text(text)
                        .font(.system(size: DS.Text.s, design: .monospaced))
                        .lineSpacing(1.5)
                        .fixedSize(horizontal: !wrapCodeLines, vertical: false)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: wrapCodeLines ? .infinity : nil, alignment: .leading)
                }
            }
        }
        .background(Color.themeBackground)
    }

    @ViewBuilder
    func binaryPlaceholder(_ data: Data) -> some View {
        VStack(spacing: DS.Spacing.l) {
            Image(systemName: fileEntry?.icon ?? "doc")
                .font(.system(size: DS.Icon.l))
                .foregroundColor(.secondary)
            Text(fileName)
                .font(.system(size: DS.Text.m, weight: .semibold))
            Text("\(data.count.formatted(.byteCount(style: .file)))")
                .font(.system(size: DS.Text.s))
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

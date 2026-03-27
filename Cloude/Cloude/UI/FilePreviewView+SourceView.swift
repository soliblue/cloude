// FilePreviewView+SourceView.swift

import SwiftUI
import CloudeShared

extension FilePreviewView {
    @ViewBuilder
    func sourceTextView(_ text: String) -> some View {
        let lines = text.components(separatedBy: "\n")
        ScrollView(wrapCodeLines ? [.vertical] : [.vertical, .horizontal], showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                if showLineNumbers && lines.count > 1 && !wrapCodeLines {
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(1...lines.count, id: \.self) { num in
                            Text("\(num)")
                                .font(.system(size: DS.Text.s, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .frame(height: DS.Text.s)
                        }
                    }
                    .padding(.leading, DS.Spacing.m)
                    .padding(.trailing, DS.Spacing.s)
                    .padding(.top, DS.Spacing.l)

                    Divider()
                }

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

import SwiftUI
import CloudeShared

extension ToolDetailSheet {
    func inputSection(_ input: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Input", systemImage: "arrow.right.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            Text(input)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.themeGray6.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    func editDiffSection(_ editInfo: EditInfo) -> some View {
        let language = toolCall.filePath.flatMap { SyntaxHighlighter.languageForPath($0) }
        return VStack(alignment: .leading, spacing: 8) {
            Label("Changes", systemImage: "arrow.left.arrow.right")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            DiffTextView(diff: editInfo.toUnifiedDiff(), language: language)
                .padding(8)
                .background(Color.themeGray6.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    func readOutputSection(_ output: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Content", systemImage: "doc.text")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            CodeBlock(
                code: Self.stripReadLineNumbers(output),
                language: toolCall.filePath.flatMap { SyntaxHighlighter.languageForPath($0) }
            )
        }
    }

    static func stripReadLineNumbers(_ output: String) -> String {
        output.components(separatedBy: "\n")
            .map { line in
                if let range = line.range(of: #"^\s*\d+\t"#, options: .regularExpression) {
                    return String(line[range.upperBound...])
                }
                if let range = line.range(of: #"^\s*\d+→"#, options: .regularExpression) {
                    return String(line[range.upperBound...])
                }
                return line
            }
            .joined(separator: "\n")
    }

    func markdownOutputSection(_ output: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Output", systemImage: "arrow.left.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            StreamingMarkdownView(text: output)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.themeGray6.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    func outputSection(_ output: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Output", systemImage: "arrow.left.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                Text(output)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if outputNeedsTruncation {
                    Divider()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            outputExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(outputExpanded ? "Show less" : "Show all \(outputLines?.count ?? 0) lines")
                                .font(.subheadline.weight(.medium))
                            Image(systemName: outputExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                }
            }
            .background(Color.themeGray6.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    func fileSection(_ path: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("File", systemImage: "doc")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)

            Button {
                if let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                   let url = URL(string: "cloude://file\(encodedPath)") {
                    openURL(url)
                    dismiss()
                }
            } label: {
                HStack {
                    Image(systemName: fileIconName(for: path.lastPathComponent))
                        .foregroundColor(fileIconColor(for: path.lastPathComponent))
                    Text(path.lastPathComponent)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.themeGray6.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
}

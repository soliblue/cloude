import SwiftUI

struct DiffScrollView: View {
    let diff: String
    var fileName: String?

    var body: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                DiffTextView(diff: diff, language: fileName.flatMap { SyntaxHighlighter.languageForPath($0) })
                    .padding()
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height, alignment: .topLeading)
            }
        }
    }
}

struct DiffTextView: View {
    let diff: String
    var language: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(parsedLines.enumerated()), id: \.offset) { _, line in
                DiffLineView(line: line, language: language)
            }
        }
        .font(.system(size: DS.Text.m, design: .monospaced))
    }

    private var parsedLines: [DiffLine] {
        diff.components(separatedBy: "\n").compactMap { raw in
            if raw.hasPrefix("diff ") || raw.hasPrefix("index ") || raw.hasPrefix("---") || raw.hasPrefix("+++") {
                return nil
            }
            if raw.hasPrefix("@@") {
                let cleaned = parseHunkHeader(raw)
                return DiffLine(text: cleaned, type: .hunk)
            }
            if raw.hasPrefix("+") {
                return DiffLine(text: String(raw.dropFirst()), type: .added)
            }
            if raw.hasPrefix("-") {
                return DiffLine(text: String(raw.dropFirst()), type: .removed)
            }
            let text = raw.hasPrefix(" ") ? String(raw.dropFirst()) : raw
            return DiffLine(text: text, type: .context)
        }
    }

    private func parseHunkHeader(_ raw: String) -> String {
        let pattern = /@@\s*-(\d+),?\d*\s*\+(\d+),?\d*\s*@@\s*(.*)/
        if let match = raw.firstMatch(of: pattern) {
            let context = String(match.3).trimmingCharacters(in: .whitespaces)
            return context.isEmpty ? "Line \(match.2)" : "\(context) - Line \(match.2)"
        }
        return raw
    }
}

struct DiffLine {
    let text: String
    let type: LineType

    enum LineType {
        case added, removed, context, hunk
    }
}

struct DiffLineView: View {
    let line: DiffLine
    var language: String?

    var body: some View {
        switch line.type {
        case .hunk:
            Text(line.text)
                .font(.system(size: DS.Text.s, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(DS.Spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.blue.opacity(DS.Opacity.s))
        case .added:
            HStack(spacing: DS.Spacing.s) {
                Text("+")
                    .foregroundStyle(Color.pastelGreen.opacity(DS.Opacity.l))
                    .frame(width: DS.Spacing.m)
                Text(SyntaxHighlighter.highlight(line.text, language: language))
            }
            .padding(.vertical, DS.Spacing.xs)
            .padding(.horizontal, DS.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pastelGreen.opacity(DS.Opacity.s))
        case .removed:
            HStack(spacing: DS.Spacing.s) {
                Text("-")
                    .foregroundStyle(Color.pastelRed.opacity(DS.Opacity.l))
                    .frame(width: DS.Spacing.m)
                Text(SyntaxHighlighter.highlight(line.text, language: language))
            }
            .padding(.vertical, DS.Spacing.xs)
            .padding(.horizontal, DS.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pastelRed.opacity(DS.Opacity.s))
        case .context:
            HStack(spacing: DS.Spacing.s) {
                Text(" ")
                    .frame(width: DS.Spacing.m)
                Text(SyntaxHighlighter.highlight(line.text, language: language))
            }
            .padding(.vertical, DS.Spacing.xs)
            .padding(.horizontal, DS.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

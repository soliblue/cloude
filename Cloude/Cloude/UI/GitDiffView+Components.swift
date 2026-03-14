import SwiftUI

struct DiffTextView: View {
    let diff: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(parsedLines.enumerated()), id: \.offset) { _, line in
                DiffLineView(line: line)
            }
        }
        .font(.system(size: 12, design: .monospaced))
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

    var body: some View {
        switch line.type {
        case .hunk:
            Text(line.text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.08))
        case .added:
            HStack(spacing: 6) {
                Text("+")
                    .foregroundStyle(.green.opacity(0.6))
                    .frame(width: 12)
                Text(line.text)
                    .foregroundStyle(.green)
            }
            .padding(.vertical, 1)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.12))
        case .removed:
            HStack(spacing: 6) {
                Text("-")
                    .foregroundStyle(.red.opacity(0.6))
                    .frame(width: 12)
                Text(line.text)
                    .foregroundStyle(.red)
            }
            .padding(.vertical, 1)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.12))
        case .context:
            HStack(spacing: 6) {
                Text(" ")
                    .frame(width: 12)
                Text(line.text)
                    .foregroundStyle(.primary.opacity(0.7))
            }
            .padding(.vertical, 1)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

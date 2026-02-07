import SwiftUI

struct DiffTextView: View {
    let diff: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                DiffLineView(line: line)
            }
        }
        .font(.system(.caption, design: .monospaced))
    }

    private var lines: [String] {
        diff.components(separatedBy: "\n")
    }
}

struct DiffLineView: View {
    let line: String

    var body: some View {
        HStack(spacing: 0) {
            Text(line)
                .foregroundColor(lineColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
        .background(backgroundColor)
    }

    private var lineColor: Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") {
            return .green
        } else if line.hasPrefix("-") && !line.hasPrefix("---") {
            return .red
        } else if line.hasPrefix("@@") {
            return .cyan
        } else if line.hasPrefix("diff") || line.hasPrefix("index") {
            return .secondary
        }
        return .primary
    }

    private var backgroundColor: Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") {
            return .green.opacity(0.1)
        } else if line.hasPrefix("-") && !line.hasPrefix("---") {
            return .red.opacity(0.1)
        } else if line.hasPrefix("@@") {
            return .blue.opacity(0.1)
        }
        return .clear
    }
}

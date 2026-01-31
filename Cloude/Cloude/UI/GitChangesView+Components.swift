import SwiftUI
import CloudeShared

struct GitFileRow: View {
    let file: GitFileStatus
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                statusBadge
                VStack(alignment: .leading, spacing: 2) {
                    Text(fileName)
                        .font(.body)
                        .lineLimit(1)
                    Text(filePath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var statusBadge: some View {
        Text(file.status)
            .font(.system(.caption, design: .monospaced).bold())
            .foregroundColor(.white)
            .frame(width: 28, height: 22)
            .background(statusColor)
            .cornerRadius(4)
    }

    private var statusColor: Color {
        switch file.status {
        case "M": return .orange
        case "A": return .green
        case "D": return .red
        case "R", "C": return .blue
        case "??": return .gray
        default: return .secondary
        }
    }

    private var fileName: String {
        (file.path as NSString).lastPathComponent
    }

    private var filePath: String {
        let dir = (file.path as NSString).deletingLastPathComponent
        return dir.isEmpty ? "." : dir
    }
}

extension GitChangesView {
    func statusIcon(for status: String) -> String {
        switch status {
        case "M": return "pencil.circle.fill"
        case "A": return "plus.circle.fill"
        case "D": return "minus.circle.fill"
        case "R": return "arrow.right.circle.fill"
        case "??": return "questionmark.circle.fill"
        default: return "circle.fill"
        }
    }
}

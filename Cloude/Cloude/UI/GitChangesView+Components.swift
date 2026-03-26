import SwiftUI
import CloudeShared

struct GitFileRow: View {
    let file: GitFileStatus
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(file.status)
                    .font(.system(size: DS.Text.s, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 18)
                    .background(statusColor)
                    .cornerRadius(3)

                HStack(spacing: 0) {
                    Text(filePath)
                        .font(.system(size: DS.Text.m))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Text(fileName)
                        .font(.system(size: DS.Text.m, weight: .medium))
                        .lineLimit(1)
                }

                Spacer()

                if let additions = file.additions, let deletions = file.deletions {
                    HStack(spacing: 4) {
                        if additions > 0 {
                            Text("+\(additions)")
                                .foregroundColor(.pastelGreen)
                        }
                        if deletions > 0 {
                            Text("-\(deletions)")
                                .foregroundColor(.pastelRed)
                        }
                    }
                    .font(.system(size: DS.Text.s, weight: .medium, design: .monospaced))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var statusIcon: String {
        switch file.status {
        case "M": return "square.and.pencil"
        case "A": return "plus"
        case "D": return "trash"
        case "R", "C": return "arrow.right"
        case "??": return "plus"
        default: return "circle"
        }
    }

    private var statusColor: Color {
        switch file.status {
        case "M": return .orange
        case "A": return .pastelGreen
        case "D": return .pastelRed
        case "R", "C": return .blue
        case "??": return .gray
        default: return .secondary
        }
    }

    private var fileName: String {
        file.path.lastPathComponent
    }

    private var filePath: String {
        let dir = file.path.deletingLastPathComponent
        return dir.isEmpty || dir == "." ? "" : dir + "/"
    }
}

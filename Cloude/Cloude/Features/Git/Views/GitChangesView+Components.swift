import SwiftUI
import CloudeShared

struct GitFileRow: View {
    let file: GitFileStatus
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.s) {
                Text(file.status)
                    .font(.system(size: DS.Text.s, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: DS.Size.m, height: DS.Icon.l)
                    .background(statusColor)
                    .cornerRadius(DS.Radius.s)

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
                    HStack(spacing: DS.Spacing.xs) {
                        if additions > 0 {
                            Text("+\(additions)")
                                .foregroundColor(AppColor.success)
                        }
                        if deletions > 0 {
                            Text("-\(deletions)")
                                .foregroundColor(AppColor.danger)
                        }
                    }
                    .font(.system(size: DS.Text.s, weight: .medium, design: .monospaced))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        AppColor.gitStatus(file.status)
    }

    private var fileName: String {
        file.path.lastPathComponent
    }

    private var filePath: String {
        let dir = file.path.deletingLastPathComponent
        return dir.isEmpty || dir == "." ? "" : dir + "/"
    }
}

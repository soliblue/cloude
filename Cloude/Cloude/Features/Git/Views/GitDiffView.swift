import SwiftUI
import CloudeShared

struct GitDiffView: View {
    let connection: ConnectionManager
    let repoPath: String
    let file: GitFileStatus
    var environmentId: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var diff: String?
    @State private var isLoading = false
    @State private var pendingDiffKey: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                fileHeader
                Divider()
                diffContent
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: DS.Icon.s, weight: .medium))
                    }
                    .agenticID("git_diff_close_button")
                }
            }
            .onAppear { loadDiff() }
        }
        .agenticID("git_diff_view")
        .onReceive(connection.events) { event in
            if case let .gitDiff(_, diffText) = event {
                diff = diffText
                isLoading = false
                AppLogger.endInterval("git.diff", key: pendingDiffKey ?? file.path, details: "chars=\(diffText.count)")
                pendingDiffKey = nil
            }
        }
    }

    private var fileHeader: some View {
        HStack {
            Label(file.statusDescription, systemImage: statusIcon)
                .font(.system(size: DS.Text.m))
                .foregroundColor(statusColor)
            if file.staged {
                Text("Staged")
                    .font(.system(size: DS.Text.s, weight: .medium))
                    .foregroundColor(AppColor.success)
                    .padding(.horizontal, DS.Spacing.s)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(AppColor.success.opacity(DS.Opacity.s))
                    .cornerRadius(DS.Radius.s)
            }
            Spacer()
            Text(file.path)
                .font(.system(size: DS.Text.s))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding()
        .background(Color.themeSecondary)
    }

    private var diffContent: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let diff = diff, !diff.isEmpty {
                DiffScrollView(diff: diff, fileName: file.path)
            } else {
                ContentUnavailableView("No Diff", systemImage: "doc.text", description: Text("No changes to show"))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fileName: String {
        file.path.lastPathComponent
    }

    private var statusIcon: String {
        switch file.status {
        case "M": return "pencil.circle.fill"
        case "A": return "plus.circle.fill"
        case "D": return "minus.circle.fill"
        case "R": return "arrow.right.circle.fill"
        case "??": return "questionmark.circle.fill"
        default: return "circle.fill"
        }
    }

    private var statusColor: Color {
        AppColor.gitStatus(file.status)
    }

    private func loadDiff() {
        pendingDiffKey = "\(repoPath)|\(file.path)|\(file.staged)"
        AppLogger.beginInterval("git.diff", key: pendingDiffKey)
        isLoading = true
        diff = nil
        connection.gitDiff(path: repoPath, file: file.path, staged: file.staged, environmentId: environmentId)
    }
}

import SwiftUI
import CloudeShared

struct GitDiffView: View {
    let environmentStore: EnvironmentStore
    let repoPath: String
    let file: GitFileStatus
    var environmentId: UUID?

    @Environment(\.appTheme) private var appTheme
    @Environment(\.dismiss) private var dismiss
    @State private var diff: String?
    @State private var isLoading = false
    @State private var pendingDiffKey: String?

    private var connection: Connection? {
        environmentStore.connectionStore.connection(for: environmentId)
    }

    private var currentDiff: String? {
        connection?.git.diffText(repoPath: repoPath, file: file.path, staged: file.staged)
    }

    private var currentDiffError: String? {
        connection?.git.diffError(repoPath: repoPath, file: file.path, staged: file.staged)
    }

    var body: some View {
        Group {
            if let connection {
                ConnectionObserver(connection: connection) { _ in
                    content
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
        NavigationStack {
            VStack(spacing: 0) {
                fileHeader
                Divider()
                diffContent
            }
            .background(Color.themeBackground(appTheme))
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
            .onAppear { loadDiff(); syncDiff() }
        }
        .agenticID("git_diff_view")
        .onChange(of: currentDiff) { _, _ in syncDiff() }
        .onChange(of: currentDiffError) { _, _ in syncDiff() }
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
        .background(Color.themeSecondary(appTheme))
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
        connection?.git.diff(path: repoPath, file: file.path, staged: file.staged)
    }

    private func syncDiff() {
        if let currentDiff {
            diff = currentDiff
            isLoading = false
            AppLogger.endInterval("git.diff", key: pendingDiffKey ?? file.path, details: "chars=\(currentDiff.count)")
            pendingDiffKey = nil
        } else if let currentDiffError {
            diff = nil
            isLoading = false
            AppLogger.cancelInterval("git.diff", key: pendingDiffKey ?? file.path, reason: currentDiffError)
            pendingDiffKey = nil
        }
    }
}

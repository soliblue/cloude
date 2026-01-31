import SwiftUI
import CloudeShared

struct GitDiffView: View {
    @ObservedObject var connection: ConnectionManager
    let repoPath: String
    let file: GitFileStatus

    @Environment(\.dismiss) private var dismiss
    @State private var diff: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                fileHeader
                Divider()
                diffContent
            }
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onAppear { loadDiff() }
        }
    }

    private var fileHeader: some View {
        HStack {
            Label(file.statusDescription, systemImage: statusIcon)
                .font(.subheadline)
                .foregroundColor(statusColor)
            Spacer()
            Text(file.path)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    private var diffContent: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let diff = diff, !diff.isEmpty {
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    DiffTextView(diff: diff)
                        .padding()
                }
            } else {
                ContentUnavailableView("No Diff", systemImage: "doc.text", description: Text("No changes to show"))
            }
        }
    }

    private var fileName: String {
        (file.path as NSString).lastPathComponent
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
        switch file.status {
        case "M": return .orange
        case "A": return .green
        case "D": return .red
        default: return .secondary
        }
    }

    private func loadDiff() {
        isLoading = true
        diff = nil

        connection.onGitDiff = { _, diffText in
            diff = diffText
            isLoading = false
        }

        connection.gitDiff(path: repoPath, file: file.path)
    }
}

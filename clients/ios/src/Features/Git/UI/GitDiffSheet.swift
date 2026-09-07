import SwiftUI
import UIKit

struct GitDiffSheet: View {
    let session: Session
    let target: GitDiffTarget
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @State private var isUpdatingIndex = false
    @State private var operationError: String?
    @State private var loadFailed = false
    @State private var lines: [GitDiffLine] = []
    @State private var truncatedFromLines: Int?
    @State private var isLoading = true
    @State private var isFullLoading = false
    @State private var search = ""

    private var visibleLines: [GitDiffLine] {
        let query = search.trimmingCharacters(in: .whitespaces)
        if query.isEmpty { return lines }
        return lines.filter {
            $0.kind == .hunk || $0.text.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        let language = FilePreviewContentType.detect(path: target.path).sourceLanguage
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(visibleLines) { line in
                        GitDiffSheetLine(line: line, language: language)
                    }
                    if let truncated = truncatedFromLines, search.isEmpty {
                        truncatedFooter(total: truncated)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.palette.background)
            .overlay {
                if isLoading { ProgressView() }
                if loadFailed && lines.isEmpty && !isLoading {
                    ContentUnavailableView {
                        Label("Diff unavailable", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("Check your server connection and try again.")
                    } actions: {
                        Button("Try again") { Task { await load(isFull: false) } }
                            .buttonStyle(.bordered)
                    }
                }
            }
            .searchable(text: $search, prompt: "Search diff")
            .navigationTitle(target.path)
            .navigationBarTitleDisplayMode(.inline)
            .themedNavChrome()
            .toolbar {
                if session.endpoint?.supportsGitMutations == true {
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            Task {
                                isUpdatingIndex = true
                                operationError = await GitMutationService.perform(
                                    target.isStaged ? "unstage" : "stage", session: session,
                                    files: [target.path], context: context)
                                isUpdatingIndex = false
                                if operationError == nil { dismiss() }
                            }
                        } label: {
                            if isUpdatingIndex {
                                ProgressView()
                            } else {
                                Label(
                                    target.isStaged ? "Unstage file" : "Stage file",
                                    systemImage: target.isStaged ? "minus.circle" : "plus.circle"
                                )
                                .labelStyle(.titleAndIcon)
                            }
                        }
                        .disabled(isUpdatingIndex)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIPasteboard.general.string = lines.map(\.raw).joined(separator: "\n")
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                    }
                    .disabled(lines.isEmpty)
                }
            }
            .task { await load(isFull: false) }
            .alert(
                "Git request failed",
                isPresented: Binding(get: { operationError != nil }, set: { if !$0 { operationError = nil } })
            ) {
                Button("OK") { operationError = nil }
            } message: {
                Text(operationError ?? "")
            }
        }
        .presentationBackground(theme.palette.background)
        .preferredColorScheme(theme.palette.colorScheme)
    }

    private func truncatedFooter(total: Int) -> some View {
        VStack(spacing: ThemeTokens.Spacing.s) {
            Text("Diff truncated, \(total) lines")
                .appFont(size: ThemeTokens.Text.s)
                .foregroundColor(ThemeColor.secondary)
            Button {
                Task { await load(isFull: true) }
            } label: {
                if isFullLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Load full diff")
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(ThemeTokens.Spacing.l)
    }

    private func load(isFull: Bool) async {
        if isFull { isFullLoading = true } else { isLoading = true }
        loadFailed = false
        if let endpoint = session.endpoint, let path = session.path {
            let result = await GitService.diff(
                endpoint: endpoint, session: session, path: path,
                file: target.path, isStaged: target.isStaged, isFull: isFull
            )
            if let result {
                lines = await GitService.parseDiff(result.text)
                truncatedFromLines = isFull ? nil : result.truncatedFromLines
            } else {
                loadFailed = true
                if isFull {
                    operationError = "The full diff could not be loaded. Check your server connection and try again."
                }
            }
        } else {
            loadFailed = true
        }
        isLoading = false
        isFullLoading = false
    }
}

import SwiftUI
import CloudeShared

extension GitChangesView {
    func statusHeader(_ status: GitStatusInfo) -> some View {
        HStack(spacing: DS.Spacing.s) {
            Text(status.branch)
                .font(.system(size: DS.Text.m, weight: .semibold))

            if status.ahead > 0 {
                Label("\(status.ahead)", systemImage: "arrow.up")
            }
            if status.behind > 0 {
                Label("\(status.behind)", systemImage: "arrow.down")
            }

            Spacer()

            let totalAdd = status.files.compactMap(\.additions).reduce(0, +)
            let totalDel = status.files.compactMap(\.deletions).reduce(0, +)
            if totalAdd > 0 || totalDel > 0 {
                HStack(spacing: DS.Spacing.xs) {
                    if totalAdd > 0 {
                        Text("+\(totalAdd)")
                            .foregroundColor(AppColor.success)
                    }
                    if totalDel > 0 {
                        Text("-\(totalDel)")
                            .foregroundColor(AppColor.danger)
                    }
                }
                .font(.system(size: DS.Text.s, weight: .medium, design: .monospaced))
                Text("·")
                    .foregroundColor(.secondary)
            }

            if !status.stagedFiles.isEmpty {
                Text("\(status.stagedFiles.count) staged")
                    .font(.system(size: DS.Text.s, weight: .medium))
                    .foregroundColor(AppColor.success)
                Text("·")
                    .foregroundColor(.secondary)
            }
            Text("\(status.unstagedFiles.count) changed")
                .font(.system(size: DS.Text.s, weight: .medium))
                .foregroundColor(status.hasChanges ? AppColor.orange : AppColor.success)
        }
        .font(.system(size: DS.Text.s))
        .foregroundColor(.secondary)
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .background(Color.themeSecondary(appTheme))
    }

    var commitsList: some View {
        Group {
            if state.recentCommits.isEmpty {
                ContentUnavailableView("No Changes", systemImage: "checkmark.circle", description: Text("Working tree clean"))
            } else {
                List {
                    Section {
                        ForEach(state.recentCommits) { commit in
                            GitCommitRow(commit: commit)
                                .listRowBackground(Color.themeBackground(appTheme))
                        }
                    } header: {
                        Text("Recent Commits")
                            .font(.system(size: DS.Text.s, weight: .semibold))
                            .textCase(.uppercase)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.themeBackground(appTheme))
                .contentMargins(.top, 0, for: .scrollContent)
            }
        }
    }

    func filesList(_ files: [GitFileStatus]) -> some View {
        let staged = files.filter { $0.staged }
        let unstaged = files.filter { !$0.staged }
        return List {
            if !staged.isEmpty {
                Section {
                    ForEach(staged) { file in
                        GitFileRow(file: file) { selectedFile = file }
                            .listRowBackground(Color.themeBackground(appTheme))
                    }
                } header: {
                    Text("Staged")
                        .font(.system(size: DS.Text.s, weight: .semibold))
                        .textCase(.uppercase)
                }
            }
            if !unstaged.isEmpty {
                Section {
                    ForEach(unstaged) { file in
                        GitFileRow(file: file) { selectedFile = file }
                            .listRowBackground(Color.themeBackground(appTheme))
                    }
                } header: {
                    Text("Changes")
                        .font(.system(size: DS.Text.s, weight: .semibold))
                        .textCase(.uppercase)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.themeBackground(appTheme))
        .contentMargins(.top, 0, for: .scrollContent)
    }
}

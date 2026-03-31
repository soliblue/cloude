import SwiftUI
import Combine
import CloudeShared

struct WindowTabBar: View {
    let activeType: WindowType
    let envConnected: Bool
    var connection: ConnectionManager? = nil
    var repoPath: String? = nil
    var environmentId: UUID? = nil
    var folderName: String? = nil
    var totalCost: Double = 0
    let onSelectType: (WindowType) -> Void
    @State private var gitAdditions: Int = 0
    @State private var gitDeletions: Int = 0
    @State private var gitBranch: String = ""

    var body: some View {
        HStack(spacing: 0) {
            #if DEBUG
            let _ = DebugMetrics.log("WindowTabBar", "render | type=\(activeType) envConn=\(envConnected)")
            #endif
            ForEach(Array(WindowType.allCases.enumerated()), id: \.element) { index, type in
                let enabled = type == .chat || envConnected
                if index > 0 {
                    Divider()
                        .frame(height: DS.Icon.m)
                }
                Button(action: {
                    if enabled { onSelectType(type) }
                }) {
                    tabLabel(for: type, enabled: enabled)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.m)
                        .contentShape(Rectangle())
                }
                .agenticID("window_tab_\(type.rawValue)")
                .buttonStyle(.plain)
            }
        }
        .padding(0)
        .background(Color.themeTertiary)
        .agenticID("window_tab_bar")
        .onReceive(connection?.events.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()) { event in
            if case let .gitStatus(path, status, envId) = event,
               path == (repoPath ?? "~"),
               envId == environmentId {
                gitAdditions = status.files.compactMap(\.additions).reduce(0, +)
                gitDeletions = status.files.compactMap(\.deletions).reduce(0, +)
                gitBranch = status.branch
            } else if case let .gitStatusError(path, _, envId) = event,
                      path == (repoPath ?? "~"),
                      envId == environmentId {
                gitAdditions = 0
                gitDeletions = 0
                gitBranch = ""
            }
        }
    }

    @ViewBuilder
    private func tabLabel(for type: WindowType, enabled: Bool) -> some View {
        let isActive = activeType == type
        if type == .chat && totalCost > 0 {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: type.icon)
                    .font(.system(size: DS.Text.m))
                Text(totalCost.asCost)
                    .font(.system(size: DS.Text.m))
            }
            .foregroundColor(isActive ? .accentColor : .secondary)
            .opacity(enabled ? 1 : DS.Opacity.m)
        } else if type == .gitChanges && (gitAdditions > 0 || gitDeletions > 0) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: type.icon)
                    .font(.system(size: DS.Text.m))
                    .foregroundColor(isActive ? .accentColor : .secondary)
                if gitAdditions > 0 {
                    Text("+\(gitAdditions)")
                        .foregroundColor(isActive ? .accentColor : .pastelGreen)
                }
                if gitDeletions > 0 {
                    Text("-\(gitDeletions)")
                        .foregroundColor(isActive ? .accentColor : .pastelRed)
                }
            }
            .font(.system(size: DS.Text.m))
            .opacity(enabled ? 1 : DS.Opacity.m)
        } else if type == .gitChanges && !gitBranch.isEmpty {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: type.icon)
                    .font(.system(size: DS.Text.m))
                Text(gitBranch.middleTruncated(limit: 8))
                    .font(.system(size: DS.Text.m))
                    .lineLimit(1)
            }
            .foregroundColor(isActive ? .accentColor : .secondary)
            .opacity(enabled ? 1 : DS.Opacity.m)
        } else if type == .files, let folderName {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: type.icon)
                    .font(.system(size: DS.Text.m))
                Text(folderName)
                    .font(.system(size: DS.Text.m))
                    .lineLimit(1)
            }
            .foregroundColor(isActive ? .accentColor : .secondary)
            .opacity(enabled ? 1 : DS.Opacity.m)
        } else {
            Image(systemName: type.icon)
                .font(.system(size: DS.Text.m, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? .accentColor : .secondary)
                .opacity(enabled ? 1 : DS.Opacity.m)
        }
    }
}

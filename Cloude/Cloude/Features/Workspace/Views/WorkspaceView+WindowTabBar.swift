import SwiftUI
import Combine
import CloudeShared

struct WindowTabBar: View, Equatable {
    let activeTab: WindowTab
    let envConnected: Bool
    var connection: ConnectionManager? = nil
    let appTheme: AppTheme
    var repoPath: String? = nil
    var environmentId: UUID? = nil
    var folderName: String? = nil
    var totalCost: Double = 0
    let onSelectTab: (WindowTab) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.activeTab == rhs.activeTab &&
        lhs.envConnected == rhs.envConnected &&
        lhs.totalCost == rhs.totalCost &&
        lhs.folderName == rhs.folderName &&
        lhs.repoPath == rhs.repoPath &&
        lhs.environmentId == rhs.environmentId &&
        lhs.appTheme == rhs.appTheme
    }
    @State private var gitAdditions: Int = 0
    @State private var gitDeletions: Int = 0
    @State private var gitBranch: String = ""

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 0) {
                #if DEBUG
                let _ = DebugMetrics.log("WindowTabBar", "render | tab=\(activeTab) envConn=\(envConnected)")
                #endif
                ForEach(Array(WindowTab.allCases.enumerated()), id: \.element) { index, tab in
                    let enabled = tab == .chat || envConnected
                    if index > 0 {
                        Divider()
                            .frame(height: DS.Icon.m)
                    }
                    Button(action: {
                        if enabled { onSelectTab(tab) }
                    }) {
                        tabLabel(for: tab, enabled: enabled)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.m)
                            .contentShape(Rectangle())
                    }
                    .agenticID("window_tab_\(tab.rawValue)")
                    .buttonStyle(.plain)
                }
            }
            .background(Color.themeBackground(appTheme))

            Divider()
        }
        .padding(0)
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
    private func tabLabel(for tab: WindowTab, enabled: Bool) -> some View {
        let isActive = activeTab == tab
        if tab == .chat && totalCost > 0 {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: tab.icon)
                    .font(.system(size: DS.Text.m, weight: .medium))
                Text(totalCost.asCost)
                    .font(.system(size: DS.Text.m, weight: .medium))
                    .monospacedDigit()
            }
            .foregroundColor(isActive ? .accentColor : .secondary)
            .opacity(enabled ? 1 : DS.Opacity.m)
        } else if tab == .gitChanges && (gitAdditions > 0 || gitDeletions > 0) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: tab.icon)
                    .font(.system(size: DS.Text.m, weight: .medium))
                    .foregroundColor(isActive ? .accentColor : .secondary)
                if gitAdditions > 0 {
                    Text("+\(gitAdditions)")
                        .monospacedDigit()
                        .foregroundColor(isActive ? .accentColor : .pastelGreen)
                }
                if gitDeletions > 0 {
                    Text("-\(gitDeletions)")
                        .monospacedDigit()
                        .foregroundColor(isActive ? .accentColor : .pastelRed)
                }
            }
            .font(.system(size: DS.Text.m, weight: .medium))
            .opacity(enabled ? 1 : DS.Opacity.m)
        } else if tab == .gitChanges && !gitBranch.isEmpty {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: tab.icon)
                    .font(.system(size: DS.Text.m, weight: .medium))
                Text(gitBranch.middleTruncated(limit: 8))
                    .font(.system(size: DS.Text.m, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(isActive ? .accentColor : .secondary)
            .opacity(enabled ? 1 : DS.Opacity.m)
        } else if tab == .files, let folderName {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: tab.icon)
                    .font(.system(size: DS.Text.m, weight: .medium))
                Text(folderName)
                    .font(.system(size: DS.Text.m, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(isActive ? .accentColor : .secondary)
            .opacity(enabled ? 1 : DS.Opacity.m)
        } else {
            Image(systemName: tab.icon)
                .font(.system(size: DS.Text.m, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? .accentColor : .secondary)
                .opacity(enabled ? 1 : DS.Opacity.m)
        }
    }
}

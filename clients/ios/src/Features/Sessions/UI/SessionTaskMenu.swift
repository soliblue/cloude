import SwiftUI

struct SessionTaskMenu: View {
    let session: Session
    @State private var renaming = false
    @State private var showingGoal = false
    @State private var showingWorktree = false
    @State private var showingPlugins = false
    @State private var showingCompaction = false
    @State private var showingReview = false
    @State private var showingShell = false
    @State private var showingTerminal = false
    @State private var showingSections = false
    @State private var showingSchedules = false
    @State private var historyEndpoint: Endpoint?
    @State private var archiveFailed = false

    var body: some View {
        Menu {
            if session.provider == .codex && session.existsOnServer {
                if session.endpoint?.capabilities?.contains("codexSections") == true {
                    Button("Move to section", systemImage: "folder") { showingSections = true }
                }
                Button("Goal", systemImage: "target") { showingGoal = true }
                if session.endpoint?.capabilities?.contains("codexCompaction") == true {
                    Button("Compact context", systemImage: "arrow.down.right.and.arrow.up.left") {
                        showingCompaction = true
                    }
                    .disabled(session.isStreaming || session.remoteIsRunning)
                }
            }
            if session.endpoint?.supportsGitWorktrees == true && session.path?.isEmpty == false && session.hasGit {
                Button("New worktree task", systemImage: "arrow.triangle.branch") { showingWorktree = true }
            }
            if session.provider == .codex && session.endpoint?.capabilities?.contains("codexPlugins") == true {
                Button("Plugins & apps", systemImage: "puzzlepiece.extension") { showingPlugins = true }
            }
            if session.provider == .codex && session.isConfigured
                && session.endpoint?.capabilities?.contains("codexReview") == true
            {
                Button("Review code", systemImage: "checkmark.bubble") { showingReview = true }
                    .disabled(session.isStreaming || session.remoteIsRunning)
            }
            if session.provider == .codex && session.isConfigured
                && session.endpoint?.capabilities?.contains("codexShell") == true
            {
                Button("Run command", systemImage: "terminal") { showingShell = true }
                    .disabled(session.isStreaming || session.remoteIsRunning)
            }
            if session.provider == .codex && session.isConfigured
                && session.endpoint?.capabilities?.contains("codexTerminal") == true
            {
                Button("Terminal", systemImage: "apple.terminal") { showingTerminal = true }
            }
            Button("Rename", systemImage: "pencil") { renaming = true }
            if session.provider == .codex && session.isConfigured
                && session.endpoint?.capabilities?.contains("agentSchedules") == true
            {
                Button("Scheduled tasks", systemImage: "calendar.badge.clock") { showingSchedules = true }
            }
            Button(session.isPinned ? "Unpin" : "Pin", systemImage: session.isPinned ? "pin.slash" : "pin") {
                SessionActions.setPinned(session, !session.isPinned)
            }
            if let endpoint = session.endpoint, endpoint.supportsCodex == true {
                Button("Remote Codex chats", systemImage: "clock.arrow.circlepath") { historyEndpoint = endpoint }
            }
            Button(session.isArchived ? "Restore" : "Archive", systemImage: "archivebox") {
                Task {
                    archiveFailed = !(await SessionService.archive(session: session, archived: !session.isArchived))
                }
            }.disabled(session.isStreaming)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Chat actions")
        .onReceive(NotificationCenter.default.publisher(for: .notificationPrepareSchedule)) { _ in
            renaming = false
            showingGoal = false
            showingWorktree = false
            showingPlugins = false
            showingCompaction = false
            showingReview = false
            showingShell = false
            showingTerminal = false
            showingSections = false
            showingSchedules = false
            historyEndpoint = nil
            archiveFailed = false
        }
        .sheet(isPresented: $showingSchedules) { ScheduleListView(session: session).id(session.connectionKey) }
        .sheet(isPresented: $showingSections) {
            if let endpoint = session.endpoint {
                SessionSectionView(endpoint: endpoint, session: session).id(session.connectionKey)
            }
        }
        .sheet(isPresented: $showingTerminal) { TerminalSheet(session: session).id(session.connectionKey) }
        .sheet(isPresented: $showingShell) { SessionShellSheet(session: session).id(session.connectionKey) }
        .sheet(isPresented: $showingReview) { SessionReviewSheet(session: session).id(session.connectionKey) }
        .sheet(isPresented: $showingCompaction) { SessionCompactionSheet(session: session).id(session.connectionKey) }
        .sheet(isPresented: $showingPlugins) { SessionPluginView(session: session).id(session.connectionKey) }
        .sheet(isPresented: $showingWorktree) { SessionWorktreeSheet(session: session).id(session.connectionKey) }
        .sheet(isPresented: $showingGoal) { ChatGoalView(session: session).id(session.connectionKey) }
        .sheet(isPresented: $renaming) { SessionRenameSheet(session: session).id(session.connectionKey) }
        .sheet(item: $historyEndpoint) {
            SessionRemoteHistoryView(endpoint: $0).id("\($0.id)|\($0.connectionRevision?.uuidString ?? "")")
        }
        .alert("Could not update this chat", isPresented: $archiveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check your connection and try again.")
        }
    }
}

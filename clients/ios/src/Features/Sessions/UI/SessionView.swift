import SwiftData
import SwiftUI

struct SessionView: View {
    @Bindable var session: Session
    let selectedTab: SessionTab
    let openSidebar: () -> Void
    let openGit: () -> Void
    @Binding var folderPickerRequest: SessionFolderPickerRequest?
    @Environment(\.modelContext) private var context
    @State private var traceId = String(UUID().uuidString.prefix(6))

    var body: some View {
        #if DEBUG
        let _ = Self._logChanges()
        #endif
        let _ = PerfCounters.bump("sv.body")
        ZStack {
            SessionViewContent(
                session: session,
                selectedTab: selectedTab,
                folderPickerRequest: $folderPickerRequest
            )
        }
        .task(id: gitRefreshKey) {
            if session.isConfigured {
                await GitService.refresh(session: session, context: context)
            }
        }
        .safeAreaInset(edge: .top) {
            SessionViewHeader(
                selectedTab: selectedTab,
                isGitSelected: false,
                sessionId: session.id,
                isConfigured: session.isConfigured,
                hasGit: session.hasGit,
                filesLabel: filesLabel,
                openSidebar: openSidebar,
                selectTab: { tab in
                    if tab == .git {
                        openGit()
                    } else {
                        withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
                            session.tab = tab
                        }
                    }
                }
            )
        }
        .onAppear {
            AppLogger.uiInfo(
                "sessionView appear trace=\(traceId) session=\(session.id.uuidString) configured=\(session.isConfigured) tab=\(selectedTab.rawValue) hasGit=\(session.hasGit)"
            )
        }
        .onDisappear {
            AppLogger.uiInfo("sessionView disappear trace=\(traceId) session=\(session.id.uuidString)")
        }
    }

    private var filesLabel: String {
        if let path = session.path, !path.isEmpty {
            let leaf = (path as NSString).lastPathComponent
            return leaf.count > 10 ? String(leaf.prefix(10)) + "…" : leaf
        }
        return SessionTab.files.label
    }

    private var gitRefreshKey: String {
        if let endpoint = session.endpoint, let path = session.path, !path.isEmpty {
            return "\(endpoint.id.uuidString)|\(path)"
        }
        return ""
    }
}

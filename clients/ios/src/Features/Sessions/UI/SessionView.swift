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
    @State private var isFilesSheetPresented = false

    var body: some View {
        #if DEBUG
        let _ = PerfCounters.enabled ? Self._logChanges() : ()
        #endif
        let _ = PerfCounters.bump("sv.body")
        ZStack {
            SessionViewContent(
                session: session,
                folderPickerRequest: $folderPickerRequest
            )
        }
        .sheet(isPresented: $isFilesSheetPresented) {
            FileTreeSheet(session: session)
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
                openSidebar: openSidebar,
                selectTab: { tab in
                    if tab == .git {
                        openGit()
                    } else if tab == .files {
                        if session.isConfigured {
                            isFilesSheetPresented = true
                        }
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

    private var gitRefreshKey: String {
        if let endpoint = session.endpoint, let path = session.path, !path.isEmpty {
            return "\(endpoint.id.uuidString)|\(path)|\(session.lastSeq)"
        }
        return ""
    }
}

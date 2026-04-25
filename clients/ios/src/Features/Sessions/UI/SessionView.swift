import SwiftData
import SwiftUI

struct SessionView: View {
    @Bindable var session: Session
    @Binding var isSidebarOpen: Bool
    @Binding var folderPickerRequest: SessionFolderPickerRequest?
    @Environment(\.modelContext) private var context
    @State private var traceId = String(UUID().uuidString.prefix(6))

    var body: some View {
        #if DEBUG
        let _ = Self._logChanges()
        #endif
        let _ = PerfCounters.bump("sv.body")
        ZStack {
            SessionViewContent(session: session, folderPickerRequest: $folderPickerRequest)
        }
        .task(id: gitRefreshKey) {
            if session.isConfigured {
                await GitService.refresh(session: session, context: context)
            }
        }
        .safeAreaInset(edge: .top) {
            SessionViewHeader(
                isSidebarOpen: $isSidebarOpen,
                selectedTab: $session.tab,
                sessionId: session.id,
                isConfigured: session.isConfigured,
                hasGit: session.hasGit,
                filesLabel: filesLabel
            )
        }
        .onAppear {
            AppLogger.uiInfo(
                "sessionView appear trace=\(traceId) session=\(session.id.uuidString) configured=\(session.isConfigured) tab=\(session.tab.rawValue) hasGit=\(session.hasGit)"
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

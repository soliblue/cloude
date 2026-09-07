import SwiftData
import SwiftUI

struct WindowsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.filePreviewPresenter) private var presenter
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Query(sort: \Window.order) private var windows: [Window]
    @Query private var endpoints: [Endpoint]
    @State private var selectedPane: WindowsPane = .session
    @State private var isOnboardingPresented = false
    @State private var onboardingInitialStep: OnboardingStep = .install
    @State private var folderPickerRequest: SessionFolderPickerRequest?
    @State private var isDaemonUpdateSheetPresented = false
    @State private var scheduleNotification: WindowsScheduleNotification?
    @State private var unavailableScheduleNotification = false
    @State private var notificationGeneration = UUID()
    @AppStorage(StorageKey.debugOverlayEnabled) private var debugOverlayEnabled = false
    private let toastStore = SessionToastStore.shared

    private var focusedSession: Session? {
        windows.first(where: { $0.isFocused })?.session
    }

    private var archivedWindowIds: [PersistentIdentifier] {
        windows.filter { $0.session?.isArchived == true }.map(\.id)
    }

    var body: some View {
        #if DEBUG
        let _ = PerfCounters.enabled ? Self._logChanges() : ()
        #endif
        let _ = PerfCounters.bump("wv.body")
        ZStack(alignment: .topTrailing) {
            theme.palette.background.ignoresSafeArea()
            WindowsPagerTrack(
                selectedPane: selectedPane,
                hasGit: focusedSession?.hasGit == true,
                selectPane: setPane
            ) {
                WindowsSidebar(selectedPane: $selectedPane)
            } session: {
                sessionPane
            } git: {
                gitPane
            }
            DebugOverlay(endpoint: focusedSession?.endpoint)

        }
        .overlay(alignment: .top) {
            if let toast = toastStore.current {
                SessionToastBanner(
                    toast: toast,
                    onTap: { activateToast(toast) },
                    onDismiss: { toastStore.dismiss() }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .animation(.smooth(duration: 0.45), value: toastStore.current?.id)
        .preferredColorScheme(theme.palette.colorScheme)
        .sheet(
            item: Binding(
                get: { presenter.target },
                set: { presenter.target = $0 }
            )
        ) { target in
            FilePreviewSheet(session: target.session, node: target.node)
        }
        .onAppear {
            if let pending = ChatNotificationDelegate.shared.consumePending() {
                activateNotification(pending)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .notificationOpenSession)) { note in
            if let route = note.object as? ChatNotificationRoute {
                _ = ChatNotificationDelegate.shared.consumePending()
                activateNotification(route)
            } else if let sessionId = note.object as? UUID {
                activateSession(sessionId)
            }
        }
        .sheet(item: $scheduleNotification) { target in
            if target.session.connectionKey == target.connectionKey {
                ScheduleListView(session: target.session, initialScheduleId: target.scheduleId.uuidString.lowercased())
                    .id(target.id)
            } else {
                ContentUnavailableView(
                    "Machine connection changed", systemImage: "network.slash",
                    description: Text("Open Scheduled tasks again from the correct machine."))
            }
        }
        .alert("Scheduled task unavailable", isPresented: $unavailableScheduleNotification) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                "The originating task or machine is no longer available here, or its daemon needs an update. Open Scheduled tasks from a saved Codex task on that machine."
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .deeplinkOpenSettings)) { _ in
            setPane(.sidebar)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openOnboarding)) { notification in
            onboardingInitialStep = notification.object as? OnboardingStep ?? .install
            isOnboardingPresented = true
        }
        .onShake { debugOverlayEnabled.toggle() }
        .onAppear {
            WindowActions.removeArchived(among: windows, context: context)
            syncFocusedSession()
        }
        .onChange(of: archivedWindowIds) { _, _ in
            WindowActions.removeArchived(among: windows, context: context)
        }
        .task {
            ChatService.resumeAllStuck(context: context)
        }
        .task(id: scenePhase) {
            if scenePhase == .active { await SessionRemoteFollowService.refreshRunning(context: context) }
        }
        .task(id: selectedPane == .sidebar) {
            if scenePhase == .active && selectedPane == .sidebar {
                await SessionRemoteFollowService.refreshRunning(context: context)
            }
        }
        .onChange(of: focusedSession?.id) { _, _ in
            syncFocusedSession()
        }
        .onChange(of: focusedSession?.tabRaw) { _, _ in
            syncFocusedSession()
        }
        .onChange(of: focusedSession?.hasGit) { _, _ in
            syncFocusedSession()
        }
        .onChange(of: selectedPane) { oldValue, newValue in
            AppLogger.uiInfo(
                "windows pane \(oldValue.rawValue)->\(newValue.rawValue) session=\(focusedSession?.id.uuidString ?? "-")"
            )
        }
        .sheet(isPresented: $isDaemonUpdateSheetPresented) {
            NavigationStack { DaemonUpdateView() }
        }
        .fullScreenCover(isPresented: $isOnboardingPresented) {
            OnboardingView(
                initialStep: onboardingInitialStep,
                onCancel: endpoints.isEmpty ? nil : { isOnboardingPresented = false }
            ) { endpoint in
                let session = WindowActions.addNew(into: context, after: windows, endpoint: endpoint)
                let request = SessionFolderPickerRequest(sessionId: session.id, endpointId: endpoint.id)
                isOnboardingPresented = false
                DispatchQueue.main.async {
                    folderPickerRequest = request
                }
            }
        }
        .onAppear {
            if endpoints.isEmpty {
                onboardingInitialStep = .install
                isOnboardingPresented = true
            }
        }
        .onChange(of: endpoints.isEmpty) { _, isEmpty in
            if isEmpty {
                onboardingInitialStep = .install
                isOnboardingPresented = true
            }
        }
    }

    private var sessionPane: some View {
        Group {
            if let session = focusedSession {
                SessionView(
                    session: session,
                    selectedTab: .chat,
                    openSidebar: { setPane(.sidebar) },
                    openGit: { setPane(.git) },
                    folderPickerRequest: $folderPickerRequest
                )
                .id(session.id)
            } else {
                theme.palette.background
            }
        }
    }

    private var gitPane: some View {
        Group {
            if let session = focusedSession {
                SessionGitView(
                    session: session,
                    openSidebar: { setPane(.sidebar) },
                    openChat: { setPane(.session) }
                )
                .id("git-\(session.id.uuidString)")
            } else {
                theme.palette.background
            }
        }
    }

    private var paneAnimation: Animation {
        .interactiveSpring(response: 0.32, dampingFraction: 0.86)
    }

    private func syncFocusedSession() {
        if let session = focusedSession {
            if !session.hasGit, selectedPane == .git {
                setPane(.session)
            } else if selectedPane != .sidebar {
                selectedPane = session.tab == .git && session.hasGit ? .git : .session
            }
        }
    }

    private func activateToast(_ toast: SessionToast) {
        switch toast.kind {
        case .daemonUpdate:
            isDaemonUpdateSheetPresented = true
        case .session(let sessionId):
            activateSession(sessionId)
        }
        toastStore.dismiss()
    }

    private func activateNotification(_ route: ChatNotificationRoute) {
        switch route {
        case .session(let sessionId):
            activateSession(sessionId)
        case .schedule(let sessionId, _, _):
            let descriptor = FetchDescriptor<Session>(predicate: #Predicate<Session> { $0.id == sessionId })
            let target = WindowsScheduleNotification(route: route, sessions: (try? context.fetch(descriptor)) ?? [])
            let generation = UUID()
            notificationGeneration = generation
            NotificationCenter.default.post(name: .notificationPrepareSchedule, object: nil)
            presenter.target = nil
            isDaemonUpdateSheetPresented = false
            isOnboardingPresented = false
            scheduleNotification = nil
            unavailableScheduleNotification = false
            WindowsNotificationPresentation.dismissPresented {
                if notificationGeneration == generation {
                    if let target, target.session.connectionKey == target.connectionKey, target.session.endpoint != nil
                    {
                        scheduleNotification = target
                    } else {
                        unavailableScheduleNotification = true
                    }
                }
            }
        }
    }

    private func activateSession(_ sessionId: UUID) {
        if let window = windows.first(where: { $0.session?.id == sessionId }) {
            withAnimation(paneAnimation) {
                WindowActions.activate(window, among: windows)
                selectedPane = .session
            }
        } else {
            let descriptor = FetchDescriptor<Session>(
                predicate: #Predicate<Session> { $0.id == sessionId }
            )
            if let session = try? context.fetch(descriptor).first {
                withAnimation(paneAnimation) {
                    WindowActions.open(session, among: windows, context: context)
                    selectedPane = .session
                }
            }
        }
    }

    private func setPane(_ pane: WindowsPane, _ animated: Bool = true) {
        let target = pane == .git && focusedSession?.hasGit != true ? .session : pane
        withAnimation(animated ? paneAnimation : nil) {
            if let session = focusedSession, target != .sidebar {
                session.tab = target == .git ? .git : .chat
            }
            selectedPane = target
        }
    }
}

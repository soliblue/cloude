import SwiftData
import SwiftUI

struct WindowsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.filePreviewPresenter) private var presenter
    @Environment(\.modelContext) private var context
    @Query(sort: \Window.order) private var windows: [Window]
    @Query private var endpoints: [Endpoint]
    @State private var selectedPane: WindowsPane = .session
    @State private var isOnboardingPresented = false
    @State private var onboardingInitialStep: OnboardingStep = .install
    @State private var folderPickerRequest: SessionFolderPickerRequest?
    @State private var isKeyboardVisible = false
    @State private var centerTabs: [UUID: SessionTab] = [:]

    private var focusedSession: Session? {
        windows.first(where: { $0.isFocused })?.session
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
            if selectedPane == .session, !isKeyboardVisible, focusedSession != nil {
                WindowsCreateButton {
                    withAnimation(paneAnimation) {
                        let session = WindowActions.addNew(into: context, after: windows)
                        centerTabs[session.id] = .chat
                        selectedPane = .session
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .zIndex(1)
            }
        }
        .preferredColorScheme(theme.palette.colorScheme)
        .sheet(
            item: Binding(
                get: { presenter.target },
                set: { presenter.target = $0 }
            )
        ) { target in
            FilePreviewSheet(session: target.session, node: target.node)
        }
        .onReceive(NotificationCenter.default.publisher(for: .deeplinkOpenSettings)) { _ in
            setPane(.sidebar)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openOnboarding)) { notification in
            onboardingInitialStep = notification.object as? OnboardingStep ?? .install
            isOnboardingPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) { isKeyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) { isKeyboardVisible = false }
        }
        .onAppear {
            syncFocusedSession()
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
        .fullScreenCover(isPresented: $isOnboardingPresented) {
            OnboardingView(initialStep: onboardingInitialStep) { endpoint in
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
                    selectedTab: resolvedCenterTab(for: session),
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
                    session: session
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
            rememberCenterTab(session)
            if !session.hasGit, selectedPane == .git {
                setPane(.session)
            } else if selectedPane != .sidebar {
                selectedPane = session.tab == .git && session.hasGit ? .git : .session
            }
        }
    }

    private func rememberCenterTab(_ session: Session) {
        if session.tab == .git {
            centerTabs[session.id] = centerTabs[session.id] ?? .chat
        } else {
            centerTabs[session.id] = session.tab
        }
    }

    private func resolvedCenterTab(for session: Session) -> SessionTab {
        if let tab = centerTabs[session.id] {
            return tab == .git ? .chat : tab
        }
        return session.tab == .git ? .chat : session.tab
    }

    private func setPane(_ pane: WindowsPane, _ animated: Bool = true) {
        let target = pane == .git && focusedSession?.hasGit != true ? .session : pane
        if animated {
            withAnimation(paneAnimation) {
                if let session = focusedSession {
                    let centerTab = resolvedCenterTab(for: session)
                    centerTabs[session.id] = centerTab
                    session.tab = target == .git ? .git : centerTab
                }
                selectedPane = target
            }
        } else {
            if let session = focusedSession {
                let centerTab = resolvedCenterTab(for: session)
                centerTabs[session.id] = centerTab
                session.tab = target == .git ? .git : centerTab
            }
            selectedPane = target
        }
    }
}

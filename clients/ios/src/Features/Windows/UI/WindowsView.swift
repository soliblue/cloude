import SwiftData
import SwiftUI

struct WindowsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.filePreviewPresenter) private var presenter
    @Environment(\.modelContext) private var context
    @Query(sort: \Window.order) private var windows: [Window]
    @Query private var endpoints: [Endpoint]
    @State private var dragTranslation: CGFloat = 0
    @State private var paneWidth: CGFloat = 0
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
        let _ = Self._logChanges()
        #endif
        let _ = PerfCounters.bump("wv.body")
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                theme.palette.background.ignoresSafeArea()
                HStack(spacing: 0) {
                    WindowsSidebar(selectedPane: $selectedPane)
                        .frame(width: proxy.size.width)
                    sessionPane
                        .frame(width: proxy.size.width)
                        .overlay(alignment: .leading) {
                            Color.black.opacity(ThemeTokens.Opacity.s)
                                .frame(width: 1)
                        }
                    gitPane
                        .frame(width: proxy.size.width)
                        .overlay(alignment: .leading) {
                            Color.black.opacity(ThemeTokens.Opacity.s)
                                .frame(width: 1)
                        }
                }
                .offset(
                    x: boundedOffset(baseOffset(width: proxy.size.width) + dragTranslation, width: proxy.size.width)
                )
                .contentShape(Rectangle())
                DebugOverlay(endpoint: focusedSession?.endpoint)
                if selectedPane == .session, !isKeyboardVisible, let session = focusedSession {
                    WindowsCreateButtonHost(session: session) {
                        withAnimation(paneAnimation) {
                            let session = WindowActions.addNew(into: context, after: windows)
                            centerTabs[session.id] = .chat
                            selectedPane = .session
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                }
            }
            .onAppear {
                paneWidth = proxy.size.width
                configurePagerGesture()
            }
            .onChange(of: proxy.size.width) { _, width in
                paneWidth = width
                configurePagerGesture()
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
            configurePagerGesture()
        }
        .onChange(of: focusedSession?.id) { _, _ in
            syncFocusedSession()
            configurePagerGesture()
        }
        .onChange(of: focusedSession?.tabRaw) { _, _ in
            syncFocusedSession()
            configurePagerGesture()
        }
        .onChange(of: focusedSession?.hasGit) { _, _ in
            syncFocusedSession()
            configurePagerGesture()
        }
        .onChange(of: selectedPane) { oldValue, newValue in
            configurePagerGesture()
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

    private func setPane(_ pane: WindowsPane) {
        let target = pane == .git && focusedSession?.hasGit != true ? .session : pane
        withAnimation(paneAnimation) {
            dragTranslation = 0
            if let session = focusedSession {
                let centerTab = resolvedCenterTab(for: session)
                centerTabs[session.id] = centerTab
                session.tab = target == .git ? .git : centerTab
            }
            selectedPane = target
        }
    }

    private func baseOffset(width: CGFloat) -> CGFloat {
        -CGFloat(selectedPane.rawValue) * width
    }

    private func boundedOffset(_ offset: CGFloat, width: CGFloat) -> CGFloat {
        let maxIndex = maxPaneIndex(for: focusedSession)
        return min(0, max(-CGFloat(maxIndex) * width, offset))
    }

    private func resolvedPane(for offset: CGFloat, session: Session?, width: CGFloat) -> WindowsPane {
        let index = Int(round(-offset / width))
        if index <= 0 { return .sidebar }
        if index >= maxPaneIndex(for: session) { return session?.hasGit == true ? .git : .session }
        return .session
    }

    private func maxPaneIndex(for session: Session?) -> Int {
        session?.hasGit == true ? WindowsPane.git.rawValue : WindowsPane.session.rawValue
    }

    private func configurePagerGesture() {
        WindowsPagerGesture.shared.install()
        WindowsPagerGesture.shared.canBeginLeft = {
            selectedPane != .sidebar
        }
        WindowsPagerGesture.shared.canBeginRight = {
            selectedPane.rawValue != maxPaneIndex(for: focusedSession)
        }
        WindowsPagerGesture.shared.onChanged = { edge, translation in
            let width = max(paneWidth, 1)
            let base = baseOffset(width: width)
            let proposed = base + translation
            dragTranslation = boundedOffset(proposed, width: width) - base
        }
        WindowsPagerGesture.shared.onFinished = { _, translation, velocity in
            let width = max(paneWidth, 1)
            let base = baseOffset(width: width)
            let projected = base + translation + velocity * 0.12
            let pane = resolvedPane(
                for: boundedOffset(projected, width: width),
                session: focusedSession,
                width: width
            )
            AppLogger.uiInfo(
                "windows settle from=\(selectedPane.rawValue) to=\(pane.rawValue) projected=\(Int(projected)) velocity=\(Int(velocity))"
            )
            setPane(pane)
        }
    }
}

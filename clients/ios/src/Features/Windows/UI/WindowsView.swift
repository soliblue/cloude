import SwiftData
import SwiftUI

struct WindowsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.filePreviewPresenter) private var presenter
    @Environment(\.modelContext) private var context
    @Query(sort: \Window.order) private var windows: [Window]
    @Query private var endpoints: [Endpoint]
    @State private var isSidebarOpen = false
    @State private var isOnboardingPresented = false
    @State private var onboardingInitialStep: OnboardingStep = .install
    @State private var folderPickerRequest: SessionFolderPickerRequest?
    @State private var isKeyboardVisible = false

    private var focusedSession: Session? {
        windows.first(where: { $0.isFocused })?.session
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            theme.palette.background.ignoresSafeArea()
            ZStack {
                ForEach(windows) { window in
                    if let session = window.session {
                        SessionView(
                            session: session,
                            isSidebarOpen: $isSidebarOpen,
                            folderPickerRequest: $folderPickerRequest
                        )
                        .opacity(window.isFocused ? 1 : 0)
                        .allowsHitTesting(window.isFocused)
                        .id(window.id)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            DebugOverlay(endpoint: focusedSession?.endpoint)
        }
        .overlay(alignment: .leading) {
            if !isSidebarOpen {
                Color.clear
                    .frame(width: ThemeTokens.Spacing.l)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 12)
                            .onEnded { value in
                                if value.translation.width > 40 {
                                    withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
                                        isSidebarOpen = true
                                    }
                                }
                            }
                    )
            }
        }
        .overlay {
            if isSidebarOpen {
                Color.black.opacity(ThemeTokens.Opacity.m)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
                            isSidebarOpen = false
                        }
                    }
            }
        }
        .overlay(alignment: .trailing) {
            if !isSidebarOpen, !isKeyboardVisible, let session = focusedSession {
                WindowsCreateButtonHost(session: session) {
                    withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
                        _ = WindowActions.addNew(into: context, after: windows)
                    }
                }
                .transition(.opacity.animation(.easeIn(duration: ThemeTokens.Duration.m)))
            }
        }
        .overlay(alignment: .leading) {
            if isSidebarOpen {
                WindowsSidebar(isOpen: $isSidebarOpen)
                    .frame(width: ThemeTokens.Size.xxl * 1.5)
                    .frame(maxHeight: .infinity)
                    .transition(.move(edge: .leading))
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
            withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) {
                isSidebarOpen = true
            }
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
}

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
                        SessionView(session: session, isSidebarOpen: $isSidebarOpen)
                            .opacity(window.isFocused ? 1 : 0)
                            .allowsHitTesting(window.isFocused)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            DebugOverlay()
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
                        WindowActions.addNew(into: context, after: windows)
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
        .onReceive(NotificationCenter.default.publisher(for: .openOnboarding)) { _ in
            isOnboardingPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) { isKeyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: ThemeTokens.Duration.s)) { isKeyboardVisible = false }
        }
        .fullScreenCover(isPresented: $isOnboardingPresented) {
            OnboardingView { endpoint in
                if let session = focusedSession {
                    SessionActions.setEndpoint(endpoint, for: session)
                }
                isOnboardingPresented = false
            }
        }
        .onAppear {
            if endpoints.isEmpty { isOnboardingPresented = true }
        }
        .onChange(of: endpoints.isEmpty) { _, isEmpty in
            if isEmpty { isOnboardingPresented = true }
        }
    }
}

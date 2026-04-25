import SwiftUI

struct WindowsPagerTrack<Sidebar: View, SessionPane: View, GitPane: View>: View {
    let selectedPane: WindowsPane
    let hasGit: Bool
    let selectPane: (WindowsPane, Bool) -> Void
    let sidebar: Sidebar
    let session: SessionPane
    let git: GitPane
    @State private var dragTranslation: CGFloat = 0
    @State private var paneWidth: CGFloat = 0

    init(
        selectedPane: WindowsPane,
        hasGit: Bool,
        selectPane: @escaping (WindowsPane, Bool) -> Void,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder session: () -> SessionPane,
        @ViewBuilder git: () -> GitPane
    ) {
        self.selectedPane = selectedPane
        self.hasGit = hasGit
        self.selectPane = selectPane
        self.sidebar = sidebar()
        self.session = session()
        self.git = git()
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                sidebar
                    .frame(width: proxy.size.width)
                session
                    .frame(width: proxy.size.width)
                    .overlay(alignment: .leading) {
                        Color.black.opacity(ThemeTokens.Opacity.s)
                            .frame(width: 1)
                    }
                git
                    .frame(width: proxy.size.width)
                    .overlay(alignment: .leading) {
                        Color.black.opacity(ThemeTokens.Opacity.s)
                            .frame(width: 1)
                    }
            }
            .offset(
                x: boundedOffset(baseOffset(width: proxy.size.width) + dragTranslation, width: proxy.size.width)
            )
            .compositingGroup()
            .contentShape(Rectangle())
            .onAppear {
                paneWidth = proxy.size.width
                configurePagerGesture()
            }
            .onChange(of: proxy.size.width) { _, width in
                paneWidth = width
                configurePagerGesture()
            }
            .onChange(of: selectedPane) { _, _ in
                configurePagerGesture()
            }
            .onChange(of: hasGit) { _, _ in
                configurePagerGesture()
            }
        }
    }

    private func baseOffset(width: CGFloat) -> CGFloat {
        -CGFloat(selectedPane.rawValue) * width
    }

    private func boundedOffset(_ offset: CGFloat, width: CGFloat) -> CGFloat {
        min(0, max(-CGFloat(maxPaneIndex) * width, offset))
    }

    private func resolvedPane(for offset: CGFloat, width: CGFloat) -> WindowsPane {
        let index = Int(round(-offset / width))
        if index <= 0 { return .sidebar }
        if index >= maxPaneIndex { return hasGit ? .git : .session }
        return .session
    }

    private var maxPaneIndex: Int {
        hasGit ? WindowsPane.git.rawValue : WindowsPane.session.rawValue
    }

    private func settleAnimation(remaining: CGFloat, velocity: CGFloat) -> Animation {
        let distance = max(abs(remaining), 1)
        let initialVelocity = max(-12, min(12, velocity / distance))
        return .interpolatingSpring(
            stiffness: 320,
            damping: 34,
            initialVelocity: initialVelocity
        )
    }

    private func configurePagerGesture() {
        WindowsPagerGesture.shared.install()
        WindowsPagerGesture.shared.canBeginLeft = {
            selectedPane != .sidebar
        }
        WindowsPagerGesture.shared.canBeginRight = {
            selectedPane.rawValue != maxPaneIndex
        }
        WindowsPagerGesture.shared.onChanged = { _, translation in
            let width = max(paneWidth, 1)
            let base = baseOffset(width: width)
            let proposed = base + translation
            dragTranslation = boundedOffset(proposed, width: width) - base
        }
        WindowsPagerGesture.shared.onFinished = { _, translation, velocity in
            let width = max(paneWidth, 1)
            let base = baseOffset(width: width)
            let current = boundedOffset(base + translation, width: width)
            let projected = base + translation + velocity * 0.12
            let pane = resolvedPane(for: boundedOffset(projected, width: width), width: width)
            let targetBase = -CGFloat(pane.rawValue) * width
            let currentDrag = current - base
            let targetDrag = targetBase - base
            AppLogger.uiInfo(
                "windows settle from=\(selectedPane.rawValue) to=\(pane.rawValue) projected=\(Int(projected)) velocity=\(Int(velocity))"
            )
            withAnimation(
                settleAnimation(remaining: targetDrag - currentDrag, velocity: velocity),
                completionCriteria: .logicallyComplete
            ) {
                dragTranslation = targetDrag
            } completion: {
                selectPane(pane, false)
                dragTranslation = 0
            }
        }
    }
}

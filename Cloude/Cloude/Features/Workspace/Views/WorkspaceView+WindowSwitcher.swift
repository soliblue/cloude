import SwiftUI

extension WorkspaceView {
    @ViewBuilder
    func windowSwitcher() -> some View {
        let items = windowManager.windows.map { window -> WindowSwitcherItem in
            let conv = window.conversation(in: conversationStore)
            let output = conv.flatMap { environmentStore.connection(for: $0.environmentId)?.output(for: $0.id) }
            let name = conv?.name ?? "New"
            let symbol = conv?.symbol ?? "bubble.left"
            return WindowSwitcherItem(id: window.id, name: name, symbol: symbol, output: output)
        }

        WindowSwitcherView(
            items: items,
            activeId: windowManager.activeWindowId,
            appTheme: appTheme,
            onSelect: { id in
                windowManager.activeWindowId = id
            },
            onLongPress: { id in
                store.beginEditingWindow(id, windowManager: windowManager)
            }
        )
        .agenticID("window_picker")
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let horizontal = abs(value.translation.width)
                    let vertical = abs(value.translation.height)
                    if horizontal > vertical,
                       let currentId = windowManager.activeWindowId,
                       let currentIndex = windowManager.windowIndex(for: currentId) {
                        let maxIndex = windowManager.windows.count - 1
                        if value.translation.width > 0 && currentIndex < maxIndex {
                            windowManager.activeWindowId = windowManager.windows[currentIndex + 1].id
                        } else if value.translation.width < 0 && currentIndex > 0 {
                            windowManager.activeWindowId = windowManager.windows[currentIndex - 1].id
                        }
                    }
                }
        )
    }
}

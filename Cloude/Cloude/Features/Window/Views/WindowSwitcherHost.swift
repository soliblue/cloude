import SwiftUI

extension WorkspaceView {
    @ViewBuilder
    func windowSwitcher() -> some View {
        let items = windowManager.windows.map { window -> WindowSwitcherEntry in
            let conv = window.conversation(in: conversationStore)
            let output = conv.flatMap { environmentStore.connectionStore.connection(for: $0.environmentId)?.conversation($0.id).output }
            let name = conv?.name ?? "New"
            let symbol = conv?.symbol ?? "bubble.left"
            return WindowSwitcherEntry(id: window.id, name: name, symbol: symbol, output: output)
        }

        WindowSwitcherView(
            items: items,
            activeId: windowManager.activeWindowId,
            appTheme: appTheme,
            onSelect: { id in
                windowManager.activeWindowId = id
            },
            onLongPress: { id in
                store.windowBeingEdited = windowManager.windows.first { $0.id == id }
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

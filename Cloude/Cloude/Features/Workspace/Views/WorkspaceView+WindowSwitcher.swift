import SwiftUI

extension WorkspaceView {
    @ViewBuilder
    func windowSwitcher() -> some View {
        let items = windowManager.windows.map { window -> WindowSwitcherView.WindowItem in
            let convId = window.conversationId
            let conv = window.conversation(in: conversationStore)
            let isStreaming = convId.map { connection.output(for: $0).phase != .idle } ?? false
            let name = conv?.name ?? "New"
            let symbol = conv?.symbol ?? "bubble.left"
            return WindowSwitcherView.WindowItem(id: window.id, name: name, symbol: symbol, isStreaming: isStreaming)
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
        .equatable()
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

private struct WindowSwitcherView: View, Equatable {
    struct WindowItem: Equatable {
        let id: UUID
        let name: String
        let symbol: String
        let isStreaming: Bool
    }

    let items: [WindowItem]
    let activeId: UUID?
    let appTheme: AppTheme
    let onSelect: (UUID) -> Void
    let onLongPress: (UUID) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.items == rhs.items && lhs.activeId == rhs.activeId && lhs.appTheme == rhs.appTheme
    }

    var body: some View {
        #if DEBUG
        let _ = DebugMetrics.log("WindowSwitcher", "render | windows=\(items.count) active=\(activeId?.uuidString.prefix(6) ?? "nil")")
        #endif
        HStack(spacing: DS.Spacing.s) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let isActive = activeId == item.id

                if index > 0 {
                    Divider().frame(height: DS.Icon.l)
                }

                Button {
                    onSelect(item.id)
                } label: {
                    windowSwitcherLabel(item: item, isActive: isActive, useSymbols: items.count >= 3)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .agenticID("window_picker_\(index)")
                .buttonStyle(.plain)
                .simultaneousGesture(
                    LongPressGesture().onEnded { _ in
                        onLongPress(item.id)
                    }
                )
            }

        }
        .padding(.horizontal, DS.Spacing.m)
        .frame(maxWidth: .infinity)
        .background(Color.themeBackground(appTheme))
    }

    @ViewBuilder
    private func windowSwitcherLabel(item: WindowItem, isActive: Bool, useSymbols: Bool) -> some View {
        let color: Color = isActive ? .accentColor : (item.isStreaming ? .accentColor : .secondary)

        if useSymbols {
            Image(systemName: item.symbol)
                .font(.system(size: DS.Icon.l, weight: isActive ? .semibold : .regular))
                .foregroundStyle(color)
                .modifier(StreamingPulseModifier(isStreaming: item.isStreaming))
        } else {
            Text(item.name)
                .font(.system(size: DS.Text.l, weight: isActive ? .semibold : .regular))
                .foregroundStyle(color)
                .lineLimit(1)
                .truncationMode(.middle)
                .modifier(StreamingPulseModifier(isStreaming: item.isStreaming))
        }
    }
}

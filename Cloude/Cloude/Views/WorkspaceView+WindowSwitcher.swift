import SwiftUI

extension WorkspaceView {
    @ViewBuilder
    func windowSwitcher() -> some View {
        let items = windowManager.windows.map { window -> WindowSwitcherView.WindowItem in
            let convId = window.conversationId
            let isStreaming = convId.map { connection.output(for: $0).isRunning } ?? false
            let name = window.conversation(in: conversationStore)?.name ?? "New"
            return WindowSwitcherView.WindowItem(id: window.id, name: name, isStreaming: isStreaming)
        }

        WindowSwitcherView(
            items: items,
            activeIndex: currentPageIndex,
            canAddWindow: windowManager.windows.count < 3,
            onSelect: { index in
                withAnimation(.easeInOut(duration: DS.Duration.m)) { currentPageIndex = index }
            },
            onAdd: addWindowWithNewChat,
            onLongPress: { index in
                if index < windowManager.windows.count {
                    editingWindow = windowManager.windows[index]
                }
            }
        )
        .equatable()
        .agenticID("window_picker")
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let maxIndex = windowManager.windows.count - 1
                    let horizontal = abs(value.translation.width)
                    let vertical = abs(value.translation.height)
                    if horizontal > vertical {
                        if value.translation.width > 0 && currentPageIndex < maxIndex {
                            withAnimation(.easeInOut(duration: DS.Duration.m)) { currentPageIndex += 1 }
                        } else if value.translation.width < 0 && currentPageIndex > 0 {
                            withAnimation(.easeInOut(duration: DS.Duration.m)) { currentPageIndex -= 1 }
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
        let isStreaming: Bool
    }

    let items: [WindowItem]
    let activeIndex: Int
    let canAddWindow: Bool
    let onSelect: (Int) -> Void
    let onAdd: () -> Void
    let onLongPress: (Int) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.items == rhs.items && lhs.activeIndex == rhs.activeIndex && lhs.canAddWindow == rhs.canAddWindow
    }

    var body: some View {
        #if DEBUG
        let _ = DebugMetrics.log("WindowSwitcher", "render | windows=\(items.count) active=\(activeIndex)")
        #endif
        HStack(spacing: DS.Spacing.s) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let isActive = activeIndex == index

                if index > 0 {
                    Divider().frame(height: DS.Icon.l)
                }

                Button {
                    onSelect(index)
                } label: {
                    windowSwitcherLabel(name: item.name, isActive: isActive, isStreaming: item.isStreaming)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .agenticID("window_picker_\(index)")
                .buttonStyle(.plain)
                .simultaneousGesture(
                    LongPressGesture().onEnded { _ in
                        onLongPress(index)
                    }
                )
            }

            if canAddWindow {
                Divider().frame(height: DS.Icon.l)
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: DS.Icon.l, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .agenticID("window_add_button")
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.m)
        .frame(maxWidth: .infinity)
        .background(Color.themeBackground)
    }

    @ViewBuilder
    private func windowSwitcherLabel(name: String, isActive: Bool, isStreaming: Bool) -> some View {
        let color: Color = isActive ? .accentColor : (isStreaming ? .accentColor : .secondary)

        Text(name)
            .font(.system(size: DS.Text.m, weight: isActive ? .semibold : .regular))
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.middle)
            .modifier(StreamingPulseModifier(isStreaming: isStreaming))
    }
}

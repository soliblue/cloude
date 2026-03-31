import SwiftUI

extension MainChatView {
    @ViewBuilder
    func pageIndicator() -> some View {
        let maxIndex = windowManager.windows.count - 1
        HStack(spacing: DS.Spacing.s) {
            #if DEBUG
            let _ = DebugMetrics.log("PageIndicator", "render | windows=\(windowManager.windows.count) active=\(currentPageIndex)")
            #endif
            ForEach(Array(windowManager.windows.indices), id: \.self) { index in
                let window = windowManager.windows[index]
                let isActive = currentPageIndex == index
                let convId = window.conversationId
                let isStreaming = convId.map { connection.output(for: $0).isRunning } ?? false
                let conversation = window.conversation(in: conversationStore)

                if index > 0 {
                    Divider().frame(height: DS.Icon.l)
                }

                Button {
                    withAnimation(.easeInOut(duration: DS.Duration.m)) { currentPageIndex = index }
                } label: {
                    windowIndicatorIcon(window: window, conversation: conversation, isActive: isActive, isStreaming: isStreaming)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .agenticID("window_picker_\(index)")
                .buttonStyle(.plain)
                .simultaneousGesture(
                    LongPressGesture().onEnded { _ in
                        editingWindow = window
                    }
                )
            }

            if windowManager.windows.count < 3 {
            Divider().frame(height: DS.Icon.l)
            Button(action: addWindowWithNewChat) {
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
        .frame(maxWidth: .infinity)
        .background(Color.themeBackground)
        .agenticID("window_picker")
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
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

    @ViewBuilder
    func windowIndicatorIcon(window: ChatWindow, conversation: Conversation?, isActive: Bool, isStreaming: Bool) -> some View {
        let color: Color = isActive ? .accentColor : (isStreaming ? .accentColor : .secondary)
        let name = conversation?.name ?? "New"

        Text(name)
            .font(.system(size: DS.Text.m, weight: isActive ? .semibold : .regular))
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.middle)
            .modifier(StreamingPulseModifier(isStreaming: isStreaming))
    }
}

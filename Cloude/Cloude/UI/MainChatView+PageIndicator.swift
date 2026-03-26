import SwiftUI

extension MainChatView {
    @ViewBuilder
    func pageIndicator() -> some View {
        let maxIndex = windowManager.windows.count - 1
        HStack(spacing: 0) {
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
                    withAnimation(.easeInOut(duration: DS.Duration.smooth)) { currentPageIndex = index }
                } label: {
                    windowIndicatorIcon(conversation: conversation, isActive: isActive, isStreaming: isStreaming)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    LongPressGesture().onEnded { _ in
                        editingWindow = window
                    }
                )
            }

            if windowManager.windows.count < 5 {
            Divider().frame(height: DS.Icon.l)
            Button(action: addWindowWithNewChat) {
                Image(systemName: "plus")
                    .font(.system(size: DS.Icon.l, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let horizontal = abs(value.translation.width)
                    let vertical = abs(value.translation.height)
                    if horizontal > vertical {
                        if value.translation.width > 0 && currentPageIndex < maxIndex {
                            withAnimation(.easeInOut(duration: DS.Duration.smooth)) { currentPageIndex += 1 }
                        } else if value.translation.width < 0 && currentPageIndex > 0 {
                            withAnimation(.easeInOut(duration: DS.Duration.smooth)) { currentPageIndex -= 1 }
                        }
                    }
                }
        )
    }

    @ViewBuilder
    func windowIndicatorIcon(conversation: Conversation?, isActive: Bool, isStreaming: Bool) -> some View {
        let weight: Font.Weight = isActive || isStreaming ? .semibold : .regular
        let color: Color = isActive ? .accentColor : (isStreaming ? .accentColor : .secondary)

        Group {
            if let symbol = conversation?.symbol, symbol.isValidSFSymbol {
                Image(systemName: symbol)
                    .font(.system(size: DS.Icon.l, weight: weight))
                    .foregroundStyle(color)
                    .modifier(StreamingPulseModifier(isStreaming: isStreaming))
            } else {
                let size: CGFloat = isActive || isStreaming ? DS.Spacing.l : DS.Size.dot
                Circle()
                    .fill(color.opacity(isActive || isStreaming ? 1.0 : DS.Opacity.strong))
                    .frame(width: size, height: size)
                    .modifier(StreamingPulseModifier(isStreaming: isStreaming))
            }
        }
    }
}

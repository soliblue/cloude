import SwiftUI

extension MainChatView {
    @ViewBuilder
    func pageIndicator() -> some View {
        let maxIndex = windowManager.windows.count - 1
        HStack(spacing: 20) {
            windowIndicatorButtons()
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
                            withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex += 1 }
                        } else if value.translation.width < 0 && currentPageIndex > 0 {
                            withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex -= 1 }
                        }
                    }
                }
        )
    }

    @ViewBuilder
    func windowIndicatorButtons() -> some View {
        ForEach(0..<5, id: \.self) { index in
            windowIndicatorButton(at: index)
        }
    }

    @ViewBuilder
    func windowIndicatorButton(at index: Int) -> some View {
        if index < windowManager.windows.count {
            let window = windowManager.windows[index]
            let isActive = currentPageIndex == index
            let convId = window.conversationId
            let isStreaming = convId.map { connection.output(for: $0).isRunning } ?? false
            let conversation = window.conversation(in: conversationStore)

            Button {
                withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex = index }
            } label: {
                windowIndicatorIcon(conversation: conversation, isActive: isActive, isStreaming: isStreaming)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture().onEnded { _ in
                    editingWindow = window
                }
            )
        } else {
            Button(action: addWindowWithNewChat) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    func windowIndicatorIcon(conversation: Conversation?, isActive: Bool, isStreaming: Bool) -> some View {
        let weight: Font.Weight = isActive || isStreaming ? .semibold : .regular
        let color: Color = isActive ? .accentColor : (isStreaming ? .accentColor : .secondary)

        Group {
            if let symbol = conversation?.symbol, symbol.isValidSFSymbol {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: weight))
                    .foregroundStyle(color)
                    .modifier(StreamingPulseModifier(isStreaming: isStreaming))
            } else {
                let size: CGFloat = isActive || isStreaming ? 15 : 10
                Circle()
                    .fill(color.opacity(isActive || isStreaming ? 1.0 : 0.3))
                    .frame(width: size, height: size)
                    .modifier(StreamingPulseModifier(isStreaming: isStreaming))
            }
        }
        .frame(height: 28)
    }
}

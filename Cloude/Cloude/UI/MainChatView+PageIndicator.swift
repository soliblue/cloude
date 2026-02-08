import SwiftUI
import CloudeShared

extension MainChatView {
    @ViewBuilder
    func pageIndicator() -> some View {
        let maxIndex = windowManager.windows.count
        HStack(spacing: 16) {
            heartbeatIndicatorButton()
            windowIndicatorButtons()
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let horizontal = abs(value.translation.width)
                    let vertical = abs(value.translation.height)
                    guard horizontal > vertical else { return }
                    if value.translation.width > 0 && currentPageIndex < maxIndex {
                        withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex += 1 }
                    } else if value.translation.width < 0 && currentPageIndex > 0 {
                        withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex -= 1 }
                    }
                }
        )
    }

    @ViewBuilder
    func heartbeatIndicatorButton() -> some View {
        let isStreaming = connection.output(for: Heartbeat.conversationId).isRunning
        let isScheduled = conversationStore.heartbeatConfig.intervalMinutes != nil

        Button {
            withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex = 0 }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: heartbeatIconName(active: isHeartbeatActive, scheduled: isScheduled))
                    .font(.system(size: 22))
                    .foregroundStyle(isScheduled || isHeartbeatActive ? Color.accentColor : .secondary)
                    .modifier(StreamingPulseModifier(isStreaming: isStreaming))

                if conversationStore.heartbeatConfig.unreadCount > 0 && !isHeartbeatActive {
                    Text(conversationStore.heartbeatConfig.unreadCount > 9 ? "9+" : "\(conversationStore.heartbeatConfig.unreadCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 14, minHeight: 14)
                        .background(Circle().fill(Color.accentColor))
                        .offset(x: 8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
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
            let isActive = currentPageIndex == index + 1
            let convId = window.conversationId
            let isStreaming = convId.map { connection.output(for: $0).isRunning } ?? false
            let conversation = window.conversationId.flatMap { conversationStore.conversation(withId: $0) }

            let hasUnread = windowManager.unreadWindowIds.contains(window.id)

            Button {
                withAnimation(.easeInOut(duration: 0.25)) { currentPageIndex = index + 1 }
            } label: {
                windowIndicatorIcon(conversation: conversation, isActive: isActive, isStreaming: isStreaming, hasUnread: hasUnread)
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
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    func heartbeatIconName(active: Bool, scheduled: Bool) -> String {
        if scheduled {
            return active ? "heart.circle.fill" : "heart.fill"
        } else {
            return active ? "heart.slash.fill" : "heart.slash"
        }
    }

    @ViewBuilder
    func windowIndicatorIcon(conversation: Conversation?, isActive: Bool, isStreaming: Bool, hasUnread: Bool = false) -> some View {
        let weight: Font.Weight = isActive || isStreaming ? .semibold : .regular
        let color: Color = isActive ? .accentColor : (isStreaming ? .accentColor : .secondary)

        VStack(spacing: 4) {
            if let symbol = conversation?.symbol, symbol.isValidSFSymbol {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: weight))
                    .foregroundStyle(color)
                    .modifier(StreamingPulseModifier(isStreaming: isStreaming))
            } else {
                let size: CGFloat = isActive || isStreaming ? 12 : 8
                Circle()
                    .fill(color.opacity(isActive || isStreaming ? 1.0 : 0.3))
                    .frame(width: size, height: size)
                    .modifier(StreamingPulseModifier(isStreaming: isStreaming))
            }

            Circle()
                .fill(Color.accentColor)
                .frame(width: 5, height: 5)
                .opacity(hasUnread && !isActive ? 1 : 0)
        }
    }
}

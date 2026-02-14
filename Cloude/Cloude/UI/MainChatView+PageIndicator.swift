import SwiftUI
import CloudeShared

extension MainChatView {
    @ViewBuilder
    func pageIndicator() -> some View {
        let maxIndex = windowManager.windows.count
        HStack(spacing: 12) {
            heartbeatIndicatorButton()

            Divider()
                .frame(height: 24)
                .opacity(0.3)

            windowIndicatorButtons()

            Divider()
                .frame(height: 24)
                .opacity(0.3)

            searchIndicatorButton()
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
            VStack(spacing: 4) {
                Image(systemName: heartbeatIconName(active: isHeartbeatActive, scheduled: isScheduled))
                    .font(.system(size: 22))
                    .foregroundStyle(
                        isScheduled || isHeartbeatActive
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            : AnyShapeStyle(.secondary)
                    )
                    .modifier(StreamingPulseModifier(isStreaming: isStreaming))
                    .frame(height: 28)
                    .overlay(alignment: .topTrailing) {
                        if conversationStore.heartbeatConfig.unreadCount > 0 && !isHeartbeatActive {
                            Text(conversationStore.heartbeatConfig.unreadCount > 9 ? "9+" : "\(conversationStore.heartbeatConfig.unreadCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 14, minHeight: 14)
                                .background(Circle().fill(Color.accentColor))
                                .offset(x: 4, y: -4)
                        }
                    }

                Circle()
                    .fill(Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(height: 39)
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
            let conversation = window.conversation(in: conversationStore)

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
                VStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)

                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
                .frame(height: 39)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    func searchIndicatorButton() -> some View {
        Button {
            showConversationSearch = true
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                    .frame(height: 28)

                Circle()
                    .fill(Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(height: 39)
        }
        .buttonStyle(.plain)
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

            Circle()
                .fill(Color.accentColor)
                .frame(width: 6, height: 6)
                .opacity(hasUnread && !isActive ? 1 : 0)
        }
        .frame(height: 39)
    }
}

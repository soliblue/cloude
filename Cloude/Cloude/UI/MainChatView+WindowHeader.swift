import SwiftUI

extension MainChatView {
    func windowHeader(for window: ChatWindow, conversation: Conversation?) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(WindowType.allCases.enumerated()), id: \.element) { index, type in
                    let envConnected = type == .chat || (conversation?.environmentId).flatMap({ connection.connection(for: $0)?.isConnected }) ?? false
                    if index > 0 {
                        Divider()
                            .frame(height: 20)
                    }
                    Button(action: {
                        if envConnected { windowManager.setWindowType(window.id, type: type) }
                    }) {
                        Image(systemName: type.icon)
                            .font(.system(size: 15, weight: window.type == type ? .semibold : .regular))
                            .foregroundColor(window.type == type ? .accentColor : .secondary)
                            .opacity(envConnected ? 1 : 0.3)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            if let envId = conversation?.environmentId,
               let env = environmentStore.environments.first(where: { $0.id == envId }) {
                let envConnected = connection.connection(for: envId)?.isConnected ?? false
                Button(action: {
                    if envConnected {
                        connection.disconnectEnvironment(envId, clearCredentials: false)
                    } else {
                        connection.connectEnvironment(envId, host: env.host, port: env.port, token: env.token, symbol: env.symbol)
                    }
                }) {
                    Image(systemName: env.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(envConnected ? .accentColor : .secondary)
                        .frame(width: 28, height: 28)
                        .background((envConnected ? Color.accentColor : Color.secondary).opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            HStack(spacing: 0) {
                Button(action: {
                    if let conv = conversation {
                        exportConversation(conv)
                        exportCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { exportCopied = false }
                    }
                }) {
                    Image(systemName: exportCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(exportCopied ? .pastelGreen : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .disabled(conversation == nil || conversation?.messages.isEmpty == true)

                Divider()
                    .frame(height: 20)

                Button(action: {
                    if let conv = conversation, conv.sessionId != nil {
                        windowManager.setActive(window.id)
                        if let newConv = conversationStore.duplicateConversation(conv) {
                            windowManager.linkToCurrentConversation(window.id, conversation: newConv)
                        }
                    }
                }) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .disabled(conversation?.sessionId == nil)

                Divider()
                    .frame(height: 20)

                Button(action: {
                    windowManager.setActive(window.id)
                    refreshTrigger.toggle()
                    refreshConversation(for: window)
                }) {
                    if let sid = window.conversation(in: conversationStore)?.sessionId,
                       refreshingSessionIds.contains(sid) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 15, height: 15)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                            .symbolEffect(.rotate, options: .nonRepeating, value: refreshTrigger)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    }
                }
                .buttonStyle(.plain)
                .disabled(
                    environmentDisconnected(for: conversation) ||
                    window.conversationId.map({ connection.output(for: $0).isRunning }) ?? false ||
                        window.conversationId
                            .flatMap({ conversationStore.conversation(withId: $0)?.sessionId })
                            .map({ refreshingSessionIds.contains($0) }) ?? false
                )

                Divider()
                    .frame(height: 20)

                Button(action: {
                    windowManager.setActive(window.id)
                    windowManager.removeWindow(window.id)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .padding(.top, 0)
        .padding(.bottom, 7)
        .background(Color.themeSecondary)
    }
}

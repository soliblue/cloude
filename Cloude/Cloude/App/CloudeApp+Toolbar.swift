import SwiftUI
import CloudeShared

extension CloudeApp {
    @ViewBuilder
    var environmentIndicators: some View {
        VStack(spacing: 4) {
            if environmentStore.environments.count > 1 {
                HStack(spacing: 8) {
                    ForEach(environmentStore.environments) { env in
                        let conn = connection.connection(for: env.id)
                        let isAuthenticated = conn?.isAuthenticated ?? false
                        let isConnecting = (conn?.isConnected ?? false) && !isAuthenticated

                        Button(action: {
                            if isAuthenticated || isConnecting {
                                connection.disconnectEnvironment(env.id, clearCredentials: false)
                            } else {
                                connection.connectEnvironment(env.id, host: env.host, port: env.port, token: env.token, symbol: env.symbol)
                            }
                        }) {
                            Image(systemName: env.symbol)
                                .font(.system(size: 11, weight: isAuthenticated ? .semibold : .regular))
                                .foregroundColor(isAuthenticated || isConnecting ? .accentColor : .secondary.opacity(0.4))
                                .modifier(StreamingPulseModifier(isStreaming: isConnecting))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            navTitlePill
        }
    }

    @ViewBuilder
    var navTitlePill: some View {
        if !windowManager.isHeartbeatShowing {
            let conversation = windowManager.activeWindow?.conversation(in: conversationStore)
            Button(action: {
                NotificationCenter.default.post(name: .editActiveWindow, object: nil)
            }) {
                HStack(spacing: 5) {
                    if let conv = conversation {
                        Text(conv.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.3), value: conv.name)
                    } else {
                        Text("Select chat...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let folder = conversation?.workingDirectory?.nilIfEmpty?.lastPathComponent {
                        Text("- \(folder)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if let conv = conversation, conv.totalCost > 0 {
                        Text("- $\(String(format: "%.2f", conv.totalCost))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

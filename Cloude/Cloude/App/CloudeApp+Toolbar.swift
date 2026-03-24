import SwiftUI
import CloudeShared

extension CloudeApp {
    @ViewBuilder
    var navTitlePill: some View {
        if !windowManager.isHeartbeatShowing {
            let conversation = windowManager.activeWindow?.conversation(in: conversationStore)
            Button(action: {
                NotificationCenter.default.post(name: .editActiveWindow, object: nil)
            }) {
                VStack(spacing: 2) {
                    if let conv = conversation {
                        Text(conv.name)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.3), value: conv.name)
                    } else {
                        Text("Select chat...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        if let envId = conversation?.environmentId,
                           let env = environmentStore.environments.first(where: { $0.id == envId }) {
                            Image(systemName: env.symbol)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if let folder = conversation?.workingDirectory?.nilIfEmpty?.lastPathComponent {
                            Text(folder)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        if let conv = conversation, conv.totalCost > 0 {
                            Text("$\(String(format: "%.2f", conv.totalCost))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

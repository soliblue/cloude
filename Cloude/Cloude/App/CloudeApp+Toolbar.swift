import SwiftUI
import CloudeShared

extension CloudeApp {
    @ViewBuilder
    var navTitlePill: some View {
        let conversation = windowManager.activeWindow?.conversation(in: conversationStore)
        Button(action: {
                NotificationCenter.default.post(name: .editActiveWindow, object: nil)
            }) {
                VStack(spacing: DS.Spacing.xs) {
                    if let conv = conversation {
                        Text(conv.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: DS.Duration.m), value: conv.name)
                    } else {
                        Text("Select chat...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: DS.Spacing.xs) {
                        if let envId = conversation?.environmentId,
                           let env = environmentStore.environments.first(where: { $0.id == envId }) {
                            Image(systemName: env.symbol)
                                .font(.system(size: DS.Text.s, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        if let folder = conversation?.workingDirectory?.nilIfEmpty?.lastPathComponent {
                            Text(folder)
                                .font(.system(size: DS.Text.s, weight: .semibold))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        if let conv = conversation, conv.totalCost > 0 {
                            Text("$\(String(format: "%.2f", conv.totalCost))")
                                .font(.system(size: DS.Text.s, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
    }
}

import SwiftUI
import CloudeShared

extension CloudeApp {
    @ViewBuilder
    var navTitlePill: some View {
        let conversation = windowManager.activeWindow?.conversation(in: conversationStore)
        Button(action: {
                NotificationCenter.default.post(name: .editActiveWindow, object: nil)
            }) {
                HStack(spacing: DS.Spacing.xs) {
                    if let envId = conversation?.environmentId,
                       let env = environmentStore.environments.first(where: { $0.id == envId }) {
                        Image(systemName: env.symbol)
                            .font(.system(size: DS.Text.s, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    if let conv = conversation {
                        Text(conv.name)
                            .font(.system(size: DS.Text.m))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: DS.Duration.m), value: conv.name)
                    } else {
                        Text("Select chat...")
                            .font(.system(size: DS.Text.m))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
    }
}

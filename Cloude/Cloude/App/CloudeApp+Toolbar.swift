import SwiftUI
import CloudeShared

extension CloudeApp {
    @ViewBuilder
    var navTitlePill: some View {
        let conversation = windowManager.activeWindow?.conversation(in: conversationStore)
        let symbol = conversation?.environmentId
            .flatMap { envId in environmentStore.environments.first { $0.id == envId }?.symbol }
        Image.safeSymbol(symbol, fallback: "bubble.left.fill")
            .font(.system(size: DS.Icon.m, weight: .medium))
            .foregroundColor(.secondary)
    }
}

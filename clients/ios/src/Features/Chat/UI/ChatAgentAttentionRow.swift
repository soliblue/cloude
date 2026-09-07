import SwiftUI

struct ChatAgentAttentionRow: View {
    let session: Session
    let notice: ChatAgentAttention
    @State private var store = SessionRemoteStore()
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
            if let endpoint = session.endpoint {
                Button {
                    Task {
                        _ = await SessionRemoteService.open(
                            threadId: notice.threadId, endpoint: endpoint, store: store, context: context)
                    }
                } label: {
                    HStack {
                        Label("Agent needs attention", systemImage: "exclamationmark.bubble")
                        Spacer()
                        if store.openingId != nil {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up.forward.app")
                        }
                    }.font(.callout)
                }
                .disabled(store.openingId != nil)
                .accessibilityLabel("Open agent task to review its request")
            }
            if let error = store.error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .padding(.horizontal, ThemeTokens.Spacing.m)
        .padding(.vertical, ThemeTokens.Spacing.xs)
    }
}

import SwiftUI

struct ChatViewMessageListGroupRetryButton: View {
    let message: ChatMessage
    @Environment(\.modelContext) private var modelContext
    @State private var isVisuallyRetrying = false
    @State private var retryStartedAt: Date?

    var body: some View {
        Button {
            ChatService.retry(message: message, context: modelContext)
        } label: {
            icon
                .font(.system(size: ThemeTokens.Icon.l))
                .foregroundColor(isVisuallyRetrying ? ThemeColor.gray : ThemeColor.danger)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: ThemeTokens.Icon.l, height: ThemeTokens.Icon.l)
        }
        .buttonStyle(.plain)
        .disabled(isVisuallyRetrying)
        .onChange(of: message.state) { _, new in
            if new == .retrying {
                retryStartedAt = .now
                isVisuallyRetrying = true
            } else {
                let elapsed = retryStartedAt.map { Date.now.timeIntervalSince($0) } ?? 0
                let remaining = max(0, 1.0 - elapsed)
                Task {
                    try? await Task.sleep(for: .seconds(remaining))
                    isVisuallyRetrying = false
                }
            }
        }
    }

    @ViewBuilder private var icon: some View {
        if isVisuallyRetrying {
            Image(systemName: "arrow.clockwise")
                .symbolEffect(.rotate, options: .repeat(.continuous))
        } else {
            Image(systemName: "exclamationmark.circle.fill")
        }
    }
}

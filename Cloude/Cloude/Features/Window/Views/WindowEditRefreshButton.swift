import SwiftUI

struct WindowEditRefreshButton: View {
    @Binding var isRefreshing: Bool
    let output: ConversationOutput?
    let onRefresh: (() async -> Void)?

    var body: some View {
        if let output {
            WindowEditObservedRefreshButton(
                isRefreshing: $isRefreshing,
                output: output,
                onRefresh: onRefresh
            )
        } else {
            WindowEditStaticRefreshButton(
                isRefreshing: $isRefreshing,
                isRunning: false,
                onRefresh: onRefresh
            )
        }
    }
}

private struct WindowEditObservedRefreshButton: View {
    @Binding var isRefreshing: Bool
    @ObservedObject var output: ConversationOutput
    let onRefresh: (() async -> Void)?

    var body: some View {
        WindowEditStaticRefreshButton(
            isRefreshing: $isRefreshing,
            isRunning: output.phase != .idle,
            onRefresh: onRefresh
        )
    }
}

private struct WindowEditStaticRefreshButton: View {
    @Binding var isRefreshing: Bool
    let isRunning: Bool
    let onRefresh: (() async -> Void)?

    var body: some View {
        Button {
            if !isRefreshing {
                isRefreshing = true
                Task {
                    await onRefresh?()
                    isRefreshing = false
                }
            }
        } label: {
            if isRefreshing {
                ProgressView()
                    .scaleEffect(DS.Scale.s)
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: DS.Icon.s, weight: .medium))
            }
        }
        .disabled(isRefreshing || isRunning)
    }
}

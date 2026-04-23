import SwiftUI

struct DebugOverlay: View {
    @AppStorage(StorageKey.debugOverlayEnabled) private var enabled = false
    let endpoint: Endpoint?

    var body: some View {
        if enabled {
            DebugOverlayPill(endpoint: endpoint)
        }
    }
}

private struct DebugOverlayPill: View {
    let endpoint: Endpoint?
    @StateObject private var counter = DebugFPSCounter()
    @Environment(\.scenePhase) private var scenePhase
    @State private var position = CGPoint(x: 70, y: 100)
    @GestureState private var dragOffset = CGSize.zero
    @State private var expanded = false
    @State private var uploadState: UploadState = .idle

    enum UploadState { case idle, sending, success, failed }

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
            HStack(spacing: ThemeTokens.Spacing.s) {
                Circle()
                    .fill(
                        counter.fps >= 55
                            ? ThemeColor.success : counter.fps >= 30 ? ThemeColor.yellow : ThemeColor.danger
                    )
                    .frame(width: ThemeTokens.Text.s, height: ThemeTokens.Text.s)
                Text("\(counter.fps) FPS")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
            }
            .contentShape(Rectangle())
            .onTapGesture { expanded.toggle() }

            if expanded {
                Button(action: sendLogs) {
                    HStack(spacing: ThemeTokens.Spacing.xs) {
                        Image(systemName: uploadIcon)
                            .frame(width: ThemeTokens.Text.s, height: ThemeTokens.Text.s)
                            .contentTransition(.symbolEffect(.replace))
                        Text(uploadLabel)
                            .appFont(size: ThemeTokens.Text.s, weight: .medium)
                    }
                }
                .disabled(endpoint == nil || uploadState == .sending)
            }
        }
        .padding(.horizontal, ThemeTokens.Spacing.s)
        .padding(.vertical, ThemeTokens.Spacing.xs)
        .glassEffect(.clear, in: .capsule)
        .position(x: position.x + dragOffset.width, y: position.y + dragOffset.height)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in state = value.translation }
                .onEnded { value in
                    let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                    let bounds = scene?.screen.bounds ?? .zero
                    position.x = min(
                        max(position.x + value.translation.width, ThemeTokens.Size.m),
                        bounds.width - ThemeTokens.Size.m)
                    position.y = min(
                        max(position.y + value.translation.height, ThemeTokens.Size.m),
                        bounds.height - ThemeTokens.Size.m)
                }
        )
        .onChange(of: scenePhase) { _, phase in counter.setPaused(phase != .active) }
    }

    private var uploadIcon: String {
        switch uploadState {
        case .idle: return "square.and.arrow.up"
        case .sending: return "ellipsis"
        case .success: return "checkmark"
        case .failed: return "xmark"
        }
    }

    private var uploadLabel: String {
        switch uploadState {
        case .idle: return "Send logs"
        case .sending: return "Sending..."
        case .success: return "Sent"
        case .failed: return "Failed"
        }
    }

    private func sendLogs() {
        if let endpoint {
            uploadState = .sending
            Task {
                uploadState =
                    await DebugLogUploader.upload(to: endpoint) == .success ? .success : .failed
                try? await Task.sleep(for: .seconds(2))
                uploadState = .idle
            }
        }
    }
}

import SwiftUI

struct DebugOverlay: View {
    @AppStorage(StorageKey.debugOverlayEnabled) private var enabled = false

    var body: some View {
        if enabled {
            DebugOverlayPill()
        }
    }
}

private struct DebugOverlayPill: View {
    @StateObject private var counter = DebugFPSCounter()
    @Environment(\.scenePhase) private var scenePhase
    @State private var position = CGPoint(x: 70, y: 100)
    @GestureState private var dragOffset = CGSize.zero

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.s) {
            Circle()
                .fill(counter.fps >= 55 ? ThemeColor.success : counter.fps >= 30 ? ThemeColor.yellow : ThemeColor.danger)
                .frame(width: ThemeTokens.Text.s, height: ThemeTokens.Text.s)
            Text("\(counter.fps) FPS")
                .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
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
                    position.x = min(max(position.x + value.translation.width, ThemeTokens.Size.m), bounds.width - ThemeTokens.Size.m)
                    position.y = min(max(position.y + value.translation.height, ThemeTokens.Size.m), bounds.height - ThemeTokens.Size.m)
                }
        )
        .onChange(of: scenePhase) { _, phase in counter.setPaused(phase != .active) }
    }
}

import SwiftUI

struct StreamingPulseModifier: ViewModifier {
    let isStreaming: Bool
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(isPulsing ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .linear(duration: 0.15), value: isPulsing)
            .onChange(of: isStreaming) { _, streaming in
                withAnimation(streaming ? nil : .linear(duration: 0.15)) {
                    isPulsing = streaming
                }
            }
            .onAppear {
                if isStreaming { isPulsing = true }
            }
    }
}

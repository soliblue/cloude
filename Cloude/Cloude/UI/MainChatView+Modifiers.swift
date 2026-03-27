import SwiftUI

struct StreamingPulseModifier: ViewModifier {
    let isStreaming: Bool
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? DS.Opacity.m : 1.0)
            .animation(isPulsing ? .easeInOut(duration: DS.Duration.l).repeatForever(autoreverses: true) : .linear(duration: DS.Duration.s), value: isPulsing)
            .onChange(of: isStreaming) { _, streaming in
                withAnimation(streaming ? nil : .linear(duration: DS.Duration.s)) {
                    isPulsing = streaming
                }
            }
            .onAppear {
                if isStreaming { isPulsing = true }
            }
    }
}

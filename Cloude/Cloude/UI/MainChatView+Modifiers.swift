import SwiftUI

struct StreamingPulseModifier: ViewModifier {
    let isStreaming: Bool
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(pulsing ? DS.Opacity.m : 1.0)
            .onChange(of: isStreaming) { _, streaming in
                if streaming {
                    withAnimation(.easeInOut(duration: DS.Duration.l).repeatForever(autoreverses: true)) { pulsing = true }
                } else {
                    withAnimation(.easeInOut(duration: DS.Duration.s)) { pulsing = false }
                }
            }
            .onAppear {
                if isStreaming {
                    withAnimation(.easeInOut(duration: DS.Duration.l).repeatForever(autoreverses: true)) { pulsing = true }
                }
            }
    }
}

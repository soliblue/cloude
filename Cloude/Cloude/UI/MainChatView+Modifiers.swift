import SwiftUI

struct StreamingPulseModifier: ViewModifier {
    let isStreaming: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isStreaming ? DS.Opacity.m : 1.0)
            .animation(isStreaming ? .easeInOut(duration: DS.Duration.l).repeatForever(autoreverses: true) : .default, value: isStreaming)
    }
}

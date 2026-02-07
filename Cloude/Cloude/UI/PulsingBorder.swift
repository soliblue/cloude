import SwiftUI

struct PulsingBorder: View {
    let isActive: Bool
    let isThinking: Bool

    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(borderColor, lineWidth: isActive ? 1.5 : 0.5)
            .opacity(isThinking ? (pulse ? 0.4 : 1.0) : 1.0)
            .animation(isThinking ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: pulse)
            .onAppear {
                if isThinking { pulse = true }
            }
            .onChange(of: isThinking) { _, thinking in
                pulse = thinking
            }
    }

    private var borderColor: Color {
        if isThinking {
            return .orange
        }
        return isActive ? .accentColor : Color(.separator)
    }
}

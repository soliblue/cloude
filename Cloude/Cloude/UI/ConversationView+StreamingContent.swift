import SwiftUI
import CloudeShared

struct QueuedBubble: View {
    let message: ChatMessage
    var skills: [Skill] = []
    let onDelete: () -> Void

    var body: some View {
        MessageBubble(message: message, skills: skills)
            .contextMenu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
}

struct StreamingContentObserver: View {
    @ObservedObject var output: ConversationOutput
    var isCompacting: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isCompacting {
                CompactingIndicator()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            if !output.text.isEmpty || !output.toolCalls.isEmpty || output.runStats != nil {
                StreamingInterleavedOutput(
                    text: output.text,
                    toolCalls: output.toolCalls,
                    runStats: output.runStats
                )
            }
        }
    }
}

struct CompactingIndicator: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.footnote.weight(.semibold))
                .rotationEffect(.degrees(pulse ? 360 : 0))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: pulse)
            Text("Compacting")
                .font(.footnote.weight(.semibold).monospaced())
        }
        .foregroundColor(.cyan)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.cyan.opacity(0.12))
        .cornerRadius(10)
        .onAppear { pulse = true }
    }
}

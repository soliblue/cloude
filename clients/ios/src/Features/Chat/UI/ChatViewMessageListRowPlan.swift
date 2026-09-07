import SwiftData
import SwiftUI

struct ChatViewMessageListRowPlan: View {
    let session: Session
    let message: ChatMessage
    @Environment(\.modelContext) private var context
    @State private var implementationFailed = false
    @State private var snapshot = ChatLiveSnapshot()

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
            HStack {
                Label("Plan", systemImage: "list.bullet.clipboard").font(.caption).foregroundStyle(.secondary)
                if message.planIsComplete == false {
                    ProgressView().controlSize(.mini).accessibilityLabel("Writing plan")
                }
            }
            if message.planIsComplete == false {
                ChatViewMessageListRowStreamingMarkdown(snapshot: snapshot)
                    .id(ObjectIdentifier(snapshot))
            } else {
                ChatViewMessageListRowMarkdown(text: message.text).equatable()
            }
            if ChatPlanService.isCompletedPlan(message, session: session) {
                Button {
                    implementationFailed = !ChatPlanService.implement(message, session: session, context: context)
                } label: {
                    Label("Implement plan", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!ChatPlanService.canImplement(message, session: session))
                .accessibilityHint("Starts implementing this plan with default permissions. Your unsent draft is kept.")
                if implementationFailed {
                    Text("Could not start this plan. Check the connection and wait for the current turn to finish.")
                        .font(.caption).foregroundStyle(.red)
                }
            }
        }
        .onChange(of: message.text, initial: true) { _, text in
            if !text.hasPrefix(snapshot.text) { snapshot = ChatLiveSnapshot() }
            snapshot.text = text
            snapshot.deltaCount += 1
        }
    }
}

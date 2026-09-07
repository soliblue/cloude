import SwiftUI

struct ChatViewMessageListRowToolPillSheetAgent: View {
    let session: Session
    let toolCall: ChatToolCall
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var store = SessionRemoteStore()

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
            ForEach(toolCall.agentActivities) { activity in
                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                    HStack {
                        if activity.isRunning && toolCall.state == .pending { ProgressView().controlSize(.small) }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.name ?? "Agent").font(.subheadline.weight(.medium))
                            Label("Last reported: \(activity.title)", systemImage: activity.symbol).font(.caption)
                                .foregroundStyle(
                                    .secondary)
                        }
                        Spacer()
                        Text(String(activity.id.prefix(8))).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    if !activity.text.isEmpty { ChatViewMessageListRowMarkdown(text: activity.text) }
                    if session.provider == .codex, let endpoint = session.endpoint {
                        Button {
                            Task {
                                if await SessionRemoteService.open(
                                    threadId: activity.id, endpoint: endpoint, store: store, context: context)
                                {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                Label("Open agent task", systemImage: "arrow.up.forward.app")
                                if store.openingId == activity.id { ProgressView().controlSize(.small) }
                            }
                        }
                        .disabled(store.openingId != nil)
                    }
                }
                .padding(ThemeTokens.Spacing.s)
            }
            if let error = store.error {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
            if let model = toolCall.parsedInput["model"] as? String, !model.isEmpty {
                LabeledContent("Requested model", value: model).font(.caption).foregroundStyle(.secondary)
            }
            if toolCall.agentActivities.isEmpty && toolCall.state == .pending {
                Text("The agent task will be available when the remote host returns its task ID.").font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let description = toolCall.parsedInput["description"] as? String,
                !description.isEmpty
            {
                ChatViewMessageListRowToolPillSheetSection(title: "Task", icon: "checklist") {
                    Text(description)
                        .appFont(size: ThemeTokens.Text.m)
                }
            }
            if let prompt = toolCall.parsedInput["prompt"] as? String, !prompt.isEmpty {
                ChatViewMessageListRowToolPillSheetSection(title: "Prompt", icon: "text.alignleft") {
                    ChatViewMessageListRowMarkdown(text: prompt)
                }
            }
            if let result = toolCall.result, !result.isEmpty, toolCall.agentActivities.isEmpty {
                ChatViewMessageListRowToolPillSheetSection(
                    title: toolCall.state == .failed ? "Error" : "Output",
                    icon: "arrow.left.circle"
                ) {
                    ChatViewMessageListRowMarkdown(text: result)
                        .foregroundColor(toolCall.state == .failed ? ThemeColor.danger : .primary)
                }
            }
        }
    }
}

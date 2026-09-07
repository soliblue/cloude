import SwiftUI

struct ChatImageGenerationView: View {
    let session: Session
    let toolCall: ChatToolCall
    @Environment(\.filePreviewPresenter) private var presenter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let image = ChatImageGeneration(input: toolCall.parsedInput, result: toolCall.result)
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.m) {
            Label(image.statusLabel, systemImage: "photo")
                .appFont(size: ThemeTokens.Text.m, weight: .semibold)
            if let failure = image.failure {
                Text(failure)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                if let limitId = image.limitId {
                    LabeledContent("Limit", value: limitId)
                }
                if let reset = image.resetsAt {
                    LabeledContent("Resets") { Text(reset, format: .dateTime.month().day().hour().minute()) }
                }
            }
            if let path = image.previewPath(relativeTo: session.path) {
                Button {
                    presenter.open(session: session, path: path)
                    dismiss()
                } label: {
                    Label("Open generated image", systemImage: "photo")
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Opens the saved image from this task's remote machine.")
                Text(path)
                    .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                    .foregroundStyle(ThemeColor.secondary)
                    .textSelection(.enabled)
            } else if image.status == "completed" && image.failure == nil {
                Text("No saved image path was provided by the host.")
                    .foregroundStyle(ThemeColor.secondary)
            }
            if let prompt = image.prompt, !prompt.isEmpty {
                ChatViewMessageListRowToolPillSheetSection(title: "Prompt", icon: "text.alignleft") {
                    Text(prompt).textSelection(.enabled)
                }
            }
            if let result = image.result, !result.isEmpty {
                ChatViewMessageListRowToolPillSheetOutput(text: result, isError: image.failure != nil)
            }
        }
        .appFont(size: ThemeTokens.Text.m)
    }
}

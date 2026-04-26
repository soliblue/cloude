import SwiftUI

struct ChatViewMessageListRowToolPillSheetWrite: View {
    let session: Session
    let toolCall: ChatToolCall

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
            if let path = toolCall.filePath {
                ChatViewMessageListRowToolPillSheetFileRow(
                    session: session, toolCall: toolCall, path: path)
            }
            if let content = toolCall.parsedInput["content"] as? String, !content.isEmpty {
                ChatViewMessageListRowToolPillSheetReadOutput(text: content, language: language)
            }
        }
    }

    private var language: String {
        guard let path = toolCall.filePath else { return "plaintext" }
        return FilePreviewContentType.detect(path: path).sourceLanguage
    }
}

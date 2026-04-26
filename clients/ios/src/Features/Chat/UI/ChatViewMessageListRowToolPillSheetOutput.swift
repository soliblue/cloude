import SwiftUI

struct ChatViewMessageListRowToolPillSheetOutput: View {
    let text: String
    let isError: Bool
    @Environment(\.appAccent) private var appAccent

    var body: some View {
        ChatViewMessageListRowToolPillSheetSection(
            title: isError ? "Error" : "Output", icon: "arrow.left.circle"
        ) {
            ChatViewMessageListRowToolPillSheetExpandableText(
                text: text, tint: appAccent.color, isError: isError)
        }
    }
}

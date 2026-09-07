import Foundation

nonisolated struct ChatDraft: Equatable, Sendable {
    var text = ""
    var references: [ChatReference] = []
    var images: [ChatDraftImage] = []
    var pastedTexts: [String] = []

    var isEmpty: Bool { text.isEmpty && images.isEmpty && pastedTexts.isEmpty && references.isEmpty }
}

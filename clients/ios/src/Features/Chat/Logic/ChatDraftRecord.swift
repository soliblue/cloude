import Foundation

nonisolated struct ChatDraftRecord: Codable {
    var version = 1
    var text: String
    var references: [ChatReference]
    var images: [UUID]
    var pastedTexts: [String]
}

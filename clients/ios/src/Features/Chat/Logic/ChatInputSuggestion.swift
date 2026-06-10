import Foundation

struct ChatInputSuggestion: Identifiable, Equatable {
    enum Kind { case skill, agent, file }

    let kind: Kind
    let title: String
    let insertText: String
    let icon: String

    var id: String { "\(title)-\(insertText)" }
}

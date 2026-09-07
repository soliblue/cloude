import Foundation

nonisolated struct ChatModel: RawRepresentable, Hashable, CaseIterable {
    let rawValue: String

    init?(rawValue: String) {
        if rawValue.isEmpty { return nil }
        self.rawValue = rawValue
    }

    static let allCases = ["opus", "sonnet", "haiku"].compactMap { ChatModel(rawValue: $0) }

    var displayName: String {
        switch rawValue {
        case "opus": "Opus"
        case "sonnet": "Sonnet"
        case "haiku": "Haiku"
        default: rawValue
        }
    }

    var symbol: String {
        switch rawValue {
        case "opus": "crown.fill"
        case "sonnet": "hare.fill"
        case "haiku": "ant.fill"
        default: "cpu"
        }
    }

    static func friendly(fromId id: String) -> (model: ChatModel, name: String)? {
        ChatModel(rawValue: id).map { ($0, $0.displayName) }
    }
}

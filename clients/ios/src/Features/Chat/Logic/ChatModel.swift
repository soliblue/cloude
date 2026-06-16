import Foundation

enum ChatModel: String, CaseIterable, Identifiable {
    case fable
    case opus
    case sonnet
    case haiku

    var displayName: String {
        switch self {
        case .fable: "Fable"
        case .opus: "Opus"
        case .sonnet: "Sonnet"
        case .haiku: "Haiku"
        }
    }

    var symbol: String {
        switch self {
        case .fable: "tornado"
        case .opus: "crown.fill"
        case .sonnet: "hare.fill"
        case .haiku: "ant.fill"
        }
    }

    var id: String { rawValue }

    static func friendly(fromId id: String) -> (model: ChatModel, name: String)? {
        let parts = id.split(separator: "-").map(String.init)
        guard parts.first == "claude", parts.count > 1 else { return nil }
        let family = parts.dropFirst().first { ChatModel(rawValue: $0) != nil }
        guard let family, let model = ChatModel(rawValue: family) else { return nil }
        let version = parts.dropFirst().filter { $0.allSatisfy(\.isNumber) && $0.count < 4 }
        let suffix = version.isEmpty ? "" : " " + version.joined(separator: ".")
        return (model, model.displayName + suffix)
    }
}

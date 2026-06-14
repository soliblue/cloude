import Foundation

enum ChatModel: String, CaseIterable {
    case fable
    case opus
    case sonnet
    case haiku
    case gpt55 = "gpt-5.5"

    enum Provider: String, Equatable {
        case claude
        case codex
    }

    var provider: Provider {
        switch self {
        case .fable, .opus, .sonnet, .haiku: .claude
        case .gpt55: .codex
        }
    }

    var displayName: String {
        switch self {
        case .fable: "Fable"
        case .opus: "Opus"
        case .sonnet: "Sonnet"
        case .haiku: "Haiku"
        case .gpt55: "gpt-5.5"
        }
    }

    var symbol: String {
        switch self {
        case .fable: "tornado"
        case .opus: "crown.fill"
        case .sonnet: "hare.fill"
        case .haiku: "ant.fill"
        case .gpt55: "terminal"
        }
    }

    static var claudeCases: [ChatModel] { allCases.filter { $0.provider == .claude } }
    static var codexCases: [ChatModel] { allCases.filter { $0.provider == .codex } }

    static func friendly(fromId id: String) -> (model: ChatModel, name: String)? {
        if let model = ChatModel(rawValue: id) {
            return (model, model.displayName)
        }
        let parts = id.split(separator: "-").map(String.init)
        guard parts.first == "claude", parts.count > 1 else { return nil }
        let family = parts.dropFirst().first { ChatModel(rawValue: $0) != nil }
        guard let family, let model = ChatModel(rawValue: family) else { return nil }
        let version = parts.dropFirst().filter { $0.allSatisfy(\.isNumber) && $0.count < 4 }
        let suffix = version.isEmpty ? "" : " " + version.joined(separator: ".")
        return (model, model.displayName + suffix)
    }
}

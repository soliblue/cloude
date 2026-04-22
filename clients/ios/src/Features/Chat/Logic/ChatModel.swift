import Foundation

enum ChatModel: String, CaseIterable {
    case opus
    case sonnet
    case haiku

    var displayName: String {
        switch self {
        case .opus: "Opus"
        case .sonnet: "Sonnet"
        case .haiku: "Haiku"
        }
    }
}

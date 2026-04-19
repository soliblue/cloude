import Foundation

enum ModelSelection: String, Codable, CaseIterable {
    case opus = "opus"
    case sonnet = "sonnet"
    case haiku = "haiku"

    var displayName: String {
        switch self {
        case .opus: return "Opus"
        case .sonnet: return "Sonnet"
        case .haiku: return "Haiku"
        }
    }
}

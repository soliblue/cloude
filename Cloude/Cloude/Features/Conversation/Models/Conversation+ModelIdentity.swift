import Foundation

enum ModelIdentity {
    case opus(version: String?)
    case sonnet
    case haiku
    case unknown(String)

    init(_ rawModel: String) {
        let lower = rawModel.lowercased()
        if lower.contains("opus") {
            if lower.contains("4-6") { self = .opus(version: "4.6") }
            else if lower.contains("4-5") { self = .opus(version: "4.5") }
            else { self = .opus(version: nil) }
        } else if lower.contains("sonnet") {
            self = .sonnet
        } else if lower.contains("haiku") {
            self = .haiku
        } else {
            self = .unknown(rawModel)
        }
    }

    var displayName: String {
        switch self {
        case .opus(let v): v.map { "Opus \($0)" } ?? "Opus"
        case .sonnet: "Sonnet"
        case .haiku: "Haiku"
        case .unknown(let raw): raw.components(separatedBy: "-").prefix(2).joined(separator: " ").capitalized
        }
    }

    var icon: String {
        switch self {
        case .opus: "crown"
        case .sonnet: "hare"
        case .haiku: "leaf"
        case .unknown: "cpu"
        }
    }
}

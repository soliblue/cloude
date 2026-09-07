import Foundation

nonisolated enum ChatEffort: String, CaseIterable {
    case none
    case minimal
    case low
    case medium
    case high
    case xhigh
    case max
    case ultra

    var displayName: String {
        switch self {
        case .none: "None"
        case .ultra: "Ultra"
        case .minimal: "Minimal"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .xhigh: "Extra High"
        case .max: "Max"
        }
    }

    var fraction: Double {
        Double(Self.allCases.firstIndex(of: self)! + 1) / Double(Self.allCases.count)
    }
}

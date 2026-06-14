import Foundation

enum ChatEffort: String, CaseIterable {
    case low
    case medium
    case high
    case xhigh
    case max

    var displayName: String {
        switch self {
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

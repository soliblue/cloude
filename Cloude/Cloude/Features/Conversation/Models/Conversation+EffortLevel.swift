import Foundation

enum EffortLevel: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case max

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .max: return "Max"
        }
    }
}

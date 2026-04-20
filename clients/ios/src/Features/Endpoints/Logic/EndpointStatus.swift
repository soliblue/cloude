import SwiftUI

enum EndpointStatus {
    case unknown
    case checking
    case reachable
    case unreachable

    var color: Color {
        switch self {
        case .unknown: return ThemeColor.gray
        case .checking: return ThemeColor.yellow
        case .reachable: return ThemeColor.success
        case .unreachable: return ThemeColor.danger
        }
    }

    var label: String {
        switch self {
        case .unknown: return "Not connected"
        case .checking: return "Connecting..."
        case .reachable: return "Connected"
        case .unreachable: return "Unreachable"
        }
    }
}

import Foundation

enum ChatPermissionMode: String, CaseIterable, Identifiable {
    case plan
    case standard = "default"
    case acceptEdits
    case bypassPermissions
    case custom

    var displayName: String {
        switch self {
        case .plan: "Plan"
        case .standard: "Default"
        case .acceptEdits: "Accept Edits"
        case .bypassPermissions: "Full Access"
        case .custom: "Custom (settings.json)"
        }
    }

    var symbol: String {
        switch self {
        case .plan: "map"
        case .standard: "checkmark.shield"
        case .acceptEdits: "square.and.pencil"
        case .bypassPermissions: "exclamationmark.shield.fill"
        case .custom: "gearshape"
        }
    }

    var id: String { rawValue }
}

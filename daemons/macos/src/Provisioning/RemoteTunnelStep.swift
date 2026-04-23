import Foundation

enum RemoteTunnelStep: CaseIterable, Identifiable {
    case identity
    case auth
    case provisioning
    case tunnel
    case reachability

    var id: String {
        title
    }

    var title: String {
        switch self {
        case .identity:
            "Local identity"
        case .auth:
            "Auth key"
        case .provisioning:
            "Provisioning server"
        case .tunnel:
            "Secure tunnel"
        case .reachability:
            "Public route"
        }
    }
}

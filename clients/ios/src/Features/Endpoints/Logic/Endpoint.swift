import Foundation
import SwiftData

@Model
final class Endpoint {
    static let defaultSymbol = "laptopcomputer"
    static let devSymbol = "testtube.2"

    @Attribute(.unique) var id: UUID
    var host: String
    var port: Int
    var name: String?
    var symbolName: String
    var createdAt: Date
    var lastCheckTimestamp: Date?
    var lastCheckReachable: Bool?
    var daemonVersion: String?
    var daemonPlatform: String?
    var supportsCodex: Bool? = nil
    var schemeRaw: String? = nil
    var capabilities: [String]? = nil
    var connectionRevision: UUID? = nil

    var cacheId: UUID { connectionRevision ?? id }

    var supportsGitMutations: Bool { capabilities?.contains("gitMutations") == true }
    var supportsGitWorktrees: Bool { capabilities?.contains("gitWorktrees") == true }

    init(
        id: UUID = UUID(),
        host: String = "",
        port: Int = 8765,
        name: String? = nil,
        symbolName: String = Endpoint.defaultSymbol,
        scheme: String? = nil
    ) {
        self.id = id
        self.host = host
        self.port = port
        self.name = name
        self.symbolName = symbolName
        self.createdAt = .now
        self.schemeRaw = scheme
    }

    var displayName: String {
        if let name, !name.isEmpty {
            return name
        }
        if !host.isEmpty {
            return host
        }
        return "New Endpoint"
    }

    var addressLabel: String {
        host.isEmpty ? "No host" : "\(host):\(port)"
    }

    var transportScheme: String { schemeRaw ?? (port == 443 ? "https" : "http") }
}

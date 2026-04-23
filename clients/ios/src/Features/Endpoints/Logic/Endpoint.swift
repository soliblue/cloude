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

    init(
        id: UUID = UUID(),
        host: String = "",
        port: Int = 8765,
        name: String? = nil,
        symbolName: String = Endpoint.defaultSymbol
    ) {
        self.id = id
        self.host = host
        self.port = port
        self.name = name
        self.symbolName = symbolName
        self.createdAt = .now
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
}

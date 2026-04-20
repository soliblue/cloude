import Foundation
import SwiftData

@Model
final class Endpoint {
    static let defaultSymbol = "laptopcomputer"
    static let devSymbol = "testtube.2"

    @Attribute(.unique) var id: UUID
    var host: String
    var port: Int
    var symbolName: String
    var createdAt: Date
    @Transient var status: EndpointStatus = .unknown

    init(
        id: UUID = UUID(),
        host: String = "",
        port: Int = 8765,
        symbolName: String = Endpoint.defaultSymbol
    ) {
        self.id = id
        self.host = host
        self.port = port
        self.symbolName = symbolName
        self.createdAt = .now
    }
}

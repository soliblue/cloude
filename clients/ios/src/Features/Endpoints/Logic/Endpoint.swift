import Foundation

struct Endpoint: Identifiable, Codable {
    let id: UUID
    var host: String
    var port: Int
    var symbolName: String
    var status: EndpointStatus = .unknown

    init(id: UUID = UUID(), host: String = "", port: Int = 8765, symbolName: String = "laptopcomputer") {
        self.id = id
        self.host = host
        self.port = port
        self.symbolName = symbolName
    }

    private enum CodingKeys: String, CodingKey { case id, host, port, symbolName }
}

extension Endpoint: Equatable {
    static func == (lhs: Endpoint, rhs: Endpoint) -> Bool {
        lhs.id == rhs.id && lhs.host == rhs.host && lhs.port == rhs.port && lhs.symbolName == rhs.symbolName
    }
}

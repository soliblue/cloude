import Foundation

struct ServerEnvironment: Codable, Identifiable, Equatable {
    let id: UUID
    var host: String
    var port: UInt16
    var token: String
    var symbol: String

    init(host: String, port: UInt16 = 8765, token: String, symbol: String = "laptopcomputer") {
        self.id = UUID()
        self.host = host
        self.port = port
        self.token = token
        self.symbol = symbol
    }
}

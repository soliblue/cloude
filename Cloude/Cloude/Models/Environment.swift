import Foundation

struct ServerEnvironment: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var host: String
    var port: UInt16
    var token: String
    var symbol: String

    init(name: String, host: String, port: UInt16 = 8765, token: String, symbol: String = "laptopcomputer") {
        self.id = UUID()
        self.name = name
        self.host = host
        self.port = port
        self.token = token
        self.symbol = symbol
    }
}

import Foundation

struct ServerEnvironment: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var host: String
    var port: UInt16
    var token: String
    var character: String

    init(name: String, host: String, port: UInt16 = 8765, token: String, character: String = "claude-on-clouds-wizard") {
        self.id = UUID()
        self.name = name
        self.host = host
        self.port = port
        self.token = token
        self.character = character
    }

    static let availableCharacters = [
        "claude-on-clouds-baby",
        "claude-on-clouds-wizard",
        "claude-on-clouds-ninja",
        "claude-on-clouds-cowboy",
        "claude-on-clouds-chef",
        "claude-on-clouds-artist",
        "claude-on-clouds-grandpa"
    ]
}

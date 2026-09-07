import Foundation

final class Session {
    let id = UUID()
    var provider = ChatProvider.codex
    var endpoint: Endpoint? = Endpoint()
    var connectionKey: String { "\(id)|\(endpoint?.revision.uuidString ?? "")" }
}

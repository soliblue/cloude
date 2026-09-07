import Foundation

@MainActor final class Session {
    let id = UUID()
    var endpoint: Endpoint?
    init(endpoint: Endpoint) { self.endpoint = endpoint }
}

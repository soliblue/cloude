import Foundation

@MainActor final class Session {
    let id = UUID()
    var endpoint: Endpoint?
    var path: String?
    var hasGit = false
}

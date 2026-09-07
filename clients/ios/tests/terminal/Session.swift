import Foundation

final class Session {
    let id = UUID()
    var endpoint: Endpoint? = Endpoint()
    var path: String? = "/srv/project"
    var connectionKey: String { "\(id)|\(endpoint?.revision.uuidString ?? "")|\(path ?? "")" }
}

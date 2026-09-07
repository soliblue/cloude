import Foundation

extension Session {
    var connectionKey: String {
        "\(id)|\(endpoint?.id.uuidString ?? "")|\(endpoint?.connectionRevision?.uuidString ?? "")|\(path ?? "")"
    }
}

import Foundation

extension Session {
    var forkScopeKey: String {
        "\(id)|\(endpoint?.id.uuidString ?? "")|\(endpoint?.transportScheme ?? "")|\(endpoint?.host ?? "")|\(endpoint?.port ?? 0)|\(path ?? "")|\(codexThreadId ?? "")"
    }
}

import Foundation

nonisolated struct SessionAppRuntime: Decodable, Identifiable {
    let id: String
    let enabled: Bool
    let callable: Bool
    let runtimeName: String?
    var status: String { !enabled ? "Disabled" : callable ? "Ready to use" : "No callable tools" }
}

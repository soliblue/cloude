import Foundation

nonisolated struct SessionPluginHook: Decodable, Identifiable {
    let key: String
    let eventName: String
    var id: String { key + eventName }
}

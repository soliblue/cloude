import Foundation

nonisolated struct SessionAppTool: Decodable, Identifiable {
    let name: String
    let title: String?
    let description: String
    let isEnabled: Bool?
    let isReadOnly: Bool?
    let disabledReason: String?
    var id: String { name }
}

import Foundation

nonisolated struct SessionPluginSkill: Decodable, Identifiable {
    let name: String
    let description: String
    let enabled: Bool
    var id: String { name }
}

import Foundation

nonisolated struct SessionPluginInterface: Decodable, Sendable {
    let displayName: String?
    let shortDescription: String?
    let longDescription: String?
    let developerName: String?
    let capabilities: [String]?
}

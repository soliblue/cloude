import Foundation

nonisolated struct SessionProjectRoot: Codable, Identifiable, Equatable, Sendable {
    let path: String
    var id: String { path }
    var isAbsolute: Bool { path.hasPrefix("/") && !path.contains("\0") }
}

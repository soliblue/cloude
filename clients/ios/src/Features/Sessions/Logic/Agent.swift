import Foundation

struct Agent: Identifiable, Codable, Equatable {
    var name: String
    var description: String

    var id: String { name }
}

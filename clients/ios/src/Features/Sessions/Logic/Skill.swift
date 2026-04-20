import Foundation

struct Skill: Identifiable, Codable, Equatable {
    var name: String
    var description: String

    var id: String { name }
}

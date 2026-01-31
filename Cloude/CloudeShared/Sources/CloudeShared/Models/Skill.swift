import Foundation

public struct Skill: Codable, Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let description: String
    public let userInvocable: Bool

    public init(name: String, description: String, userInvocable: Bool = true) {
        self.name = name
        self.description = description
        self.userInvocable = userInvocable
    }

    enum CodingKeys: String, CodingKey {
        case name, description
        case userInvocable = "user_invocable"
    }
}

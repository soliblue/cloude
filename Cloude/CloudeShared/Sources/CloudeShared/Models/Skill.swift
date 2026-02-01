import Foundation

public struct Skill: Codable, Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let description: String
    public let userInvocable: Bool
    public let icon: String?
    public let aliases: [String]

    public init(name: String, description: String, userInvocable: Bool = true, icon: String? = nil, aliases: [String] = []) {
        self.name = name
        self.description = description
        self.userInvocable = userInvocable
        self.icon = icon
        self.aliases = aliases
    }

    enum CodingKeys: String, CodingKey {
        case name, description, icon, aliases
        case userInvocable = "user_invocable"
    }
}

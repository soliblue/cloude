import Foundation

public struct SkillParameter: Codable, Hashable {
    public let name: String
    public let placeholder: String
    public let required: Bool

    public init(name: String, placeholder: String, required: Bool = true) {
        self.name = name
        self.placeholder = placeholder
        self.required = required
    }
}

public struct Skill: Codable, Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let description: String
    public let userInvocable: Bool
    public let icon: String?
    public let aliases: [String]
    public let parameters: [SkillParameter]

    public init(name: String, description: String, userInvocable: Bool = true, icon: String? = nil, aliases: [String] = [], parameters: [SkillParameter] = []) {
        self.name = name
        self.description = description
        self.userInvocable = userInvocable
        self.icon = icon
        self.aliases = aliases
        self.parameters = parameters
    }

    enum CodingKeys: String, CodingKey {
        case name, description, icon, aliases, parameters
        case userInvocable = "user_invocable"
    }
}

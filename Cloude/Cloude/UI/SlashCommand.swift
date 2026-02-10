import SwiftUI
import CloudeShared

struct SlashCommand {
    let name: String
    let description: String
    let icon: String
    let isSkill: Bool
    let resolvesTo: String?
    let parameters: [SkillParameter]

    init(name: String, description: String, icon: String, isSkill: Bool = false, resolvesTo: String? = nil, parameters: [SkillParameter] = []) {
        self.name = name
        self.description = description
        self.icon = icon
        self.isSkill = isSkill
        self.resolvesTo = resolvesTo
        self.parameters = parameters
    }

    var hasParameters: Bool { !parameters.isEmpty }

    static func fromSkill(_ skill: Skill) -> [SlashCommand] {
        let icon = skill.icon ?? "hammer.circle"
        var commands = [SlashCommand(name: skill.name, description: skill.description, icon: icon, isSkill: true, parameters: skill.parameters)]
        for alias in skill.aliases {
            commands.append(SlashCommand(name: alias, description: skill.description, icon: icon, isSkill: true, resolvesTo: skill.name, parameters: skill.parameters))
        }
        return commands
    }
}

let builtInCommands: [SlashCommand] = [
    SlashCommand(name: "compact", description: "Compress conversation context", icon: "arrow.triangle.2.circlepath"),
    SlashCommand(name: "context", description: "Show token usage", icon: "chart.pie"),
    SlashCommand(name: "cost", description: "Show usage stats", icon: "dollarsign.circle"),
    SlashCommand(name: "usage", description: "Usage statistics", icon: "chart.bar.fill"),
]

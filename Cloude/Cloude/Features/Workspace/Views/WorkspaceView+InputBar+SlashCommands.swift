import SwiftUI
import CloudeShared

struct SlashCommand {
    let name: String
    let icon: String
    let isSkill: Bool
    let resolvesTo: String?
    let parameters: [SkillParameter]

    init(name: String, icon: String, isSkill: Bool = false, resolvesTo: String? = nil, parameters: [SkillParameter] = []) {
        self.name = name
        self.icon = icon
        self.isSkill = isSkill
        self.resolvesTo = resolvesTo
        self.parameters = parameters
    }

    var hasParameters: Bool { !parameters.isEmpty }

    static func fromSkill(_ skill: Skill) -> [SlashCommand] {
        let icon = skill.icon ?? "hammer.circle"
        var commands = [SlashCommand(name: skill.name, icon: icon, isSkill: true, parameters: skill.parameters)]
        for alias in skill.aliases {
            commands.append(SlashCommand(name: alias, icon: icon, isSkill: true, resolvesTo: skill.name, parameters: skill.parameters))
        }
        return commands
    }
}

let builtInCommands: [SlashCommand] = [
    SlashCommand(name: "compact", icon: "arrow.triangle.2.circlepath"),
    SlashCommand(name: "context", icon: "chart.pie"),
    SlashCommand(name: "cost", icon: "dollarsign.circle"),
    SlashCommand(name: "settings", icon: "gearshape"),
    SlashCommand(name: "whiteboard", icon: "pencil.and.outline"),
]

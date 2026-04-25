import SwiftUI

struct ChatInputBarAutocompletePicker: View {
    enum Mode: Equatable {
        case ambient
        case skills(query: String)
        case agents(query: String)
    }

    let mode: Mode
    let skills: [Skill]
    let agents: [Agent]
    var onSelectSkill: (String) -> Void
    var onSelectAgent: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ThemeTokens.Spacing.xs) {
                ForEach(filteredSkills) { skill in
                    ChatInputBarSkillPill(name: skill.name) { onSelectSkill(skill.name) }
                }
                ForEach(filteredAgents) { agent in
                    ChatInputBarAgentPill(name: agent.name) { onSelectAgent(agent.name) }
                }
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
        }
        .scrollClipDisabled()
    }

    private var filteredSkills: [Skill] {
        switch mode {
        case .ambient: return Array(skills.prefix(20))
        case .skills(let q):
            let lowered = q.lowercased()
            return Array(skills.filter { lowered.isEmpty || $0.name.lowercased().hasPrefix(lowered) }.prefix(8))
        case .agents: return []
        }
    }

    private var filteredAgents: [Agent] {
        switch mode {
        case .ambient: return Array(agents.prefix(20))
        case .skills: return []
        case .agents(let q):
            let lowered = q.lowercased()
            return Array(agents.filter { lowered.isEmpty || $0.name.lowercased().hasPrefix(lowered) }.prefix(8))
        }
    }
}

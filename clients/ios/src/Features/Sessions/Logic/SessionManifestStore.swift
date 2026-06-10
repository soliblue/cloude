import Foundation

@MainActor
enum SessionManifestStore {
    private static var skillsById: [UUID: [Skill]] = [:]
    private static var agentsById: [UUID: [Agent]] = [:]

    static func set(skills: [Skill], agents: [Agent], for sessionId: UUID) {
        skillsById[sessionId] = skills
        agentsById[sessionId] = agents
    }

    static func skills(for sessionId: UUID) -> [Skill] { skillsById[sessionId] ?? [] }
    static func agents(for sessionId: UUID) -> [Agent] { agentsById[sessionId] ?? [] }
}

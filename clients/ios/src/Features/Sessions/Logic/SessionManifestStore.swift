import Foundation

@MainActor
enum SessionManifestStore {
    private static var skillsById: [UUID: [Skill]] = [:]
    private static var agentsById: [UUID: [Agent]] = [:]
    private static var transcriptionById: [UUID: Bool] = [:]

    static func set(skills: [Skill], agents: [Agent], transcription: Bool, for sessionId: UUID) {
        skillsById[sessionId] = skills
        agentsById[sessionId] = agents
        transcriptionById[sessionId] = transcription
    }

    static func skills(for sessionId: UUID) -> [Skill] { skillsById[sessionId] ?? [] }
    static func agents(for sessionId: UUID) -> [Agent] { agentsById[sessionId] ?? [] }
    static func transcriptionReady(for sessionId: UUID) -> Bool {
        transcriptionById[sessionId] ?? false
    }
}

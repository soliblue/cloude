import Foundation

@MainActor
@Observable
final class SessionManifestStore {
    static let shared = SessionManifestStore()

    private var skillsById: [UUID: [Skill]] = [:]
    private var agentsById: [UUID: [Agent]] = [:]
    private var transcriptionById: [UUID: Bool] = [:]

    func set(skills: [Skill], agents: [Agent], transcription: Bool, for sessionId: UUID) {
        skillsById[sessionId] = skills
        agentsById[sessionId] = agents
        transcriptionById[sessionId] = transcription
    }

    func skills(for sessionId: UUID) -> [Skill] { skillsById[sessionId] ?? [] }
    func agents(for sessionId: UUID) -> [Agent] { agentsById[sessionId] ?? [] }
    func transcriptionReady(for sessionId: UUID) -> Bool { transcriptionById[sessionId] ?? false }
}

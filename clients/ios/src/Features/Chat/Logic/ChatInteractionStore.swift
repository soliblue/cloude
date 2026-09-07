import Foundation
import Observation

@Observable
final class ChatInteractionStore {
    static let shared = ChatInteractionStore()
    var requests: [UUID: [ChatInteraction]] = [:]
    var agentRequests: [UUID: [ChatAgentAttention]] = [:]
    var agentRevisions: [UUID: Int] = [:]
    var submitting: Set<String> = []
    var errors: [String: String] = [:]
    var revisions: [UUID: Int] = [:]

    func add(_ request: ChatInteraction, sessionId: UUID) -> Bool {
        if requests[sessionId]?.contains(where: { $0.id == request.id }) != true {
            requests[sessionId, default: []].append(request)
            revisions[sessionId, default: 0] += 1
            return true
        }
        return false
    }

    func remove(_ requestId: String, sessionId: UUID) {
        requests[sessionId]?.removeAll { $0.id == requestId }
        errors.removeValue(forKey: requestId)
        revisions[sessionId, default: 0] += 1
    }

    func clear(sessionId: UUID, includingAgents: Bool = true) {
        if includingAgents {
            agentRequests.removeValue(forKey: sessionId)
            agentRevisions[sessionId, default: 0] += 1
        }
        requests.removeValue(forKey: sessionId)
        revisions[sessionId, default: 0] += 1
    }

    func hasAttention(sessionId: UUID) -> Bool {
        !(requests[sessionId] ?? []).isEmpty || !(agentRequests[sessionId] ?? []).isEmpty
    }

    func updateAgent(threadId: String, requestId: String, pending: Bool, sessionId: UUID) {
        if pending {
            if agentRequests[sessionId]?.contains(where: { $0.requestId == requestId }) != true {
                agentRequests[sessionId, default: []].append(
                    ChatAgentAttention(threadId: threadId, requestId: requestId))
            }
        } else {
            agentRequests[sessionId]?.removeAll { $0.requestId == requestId }
        }
        agentRevisions[sessionId, default: 0] += 1
    }

    func replaceAgents(_ next: [ChatAgentAttention], sessionId: UUID, revision: Int) -> Bool {
        if agentRevisions[sessionId, default: 0] == revision {
            if agentRequests[sessionId] != next { agentRequests[sessionId] = next }
            agentRevisions[sessionId, default: 0] += 1
            return true
        }
        return false
    }

    func replace(_ next: [ChatInteraction], sessionId: UUID, revision: Int) -> Bool {
        if revisions[sessionId, default: 0] == revision {
            if requests[sessionId] != next { requests[sessionId] = next }
            revisions[sessionId, default: 0] += 1
            return true
        }
        return false
    }
}

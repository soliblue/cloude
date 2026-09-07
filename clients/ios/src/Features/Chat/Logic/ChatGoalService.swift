import Foundation

@MainActor
enum ChatGoalService {
    static func refresh(session: Session) async -> Bool {
        if session.provider == .codex, session.existsOnServer, let endpoint = session.endpoint,
            let requestId = ChatGoalRequestStore.begin(sessionId: session.id, mutating: false)
        {
            let result = await HTTPClient.get(
                endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/goal", timeout: 10)
            if ChatGoalRequestStore.finish(requestId, sessionId: session.id), !Task.isCancelled,
                let (data, response) = result, response.statusCode == 200,
                let value = try? JSONDecoder().decode(ChatGoalResponse.self, from: data)
            {
                SessionActions.setGoal(value.goal, for: session)
                return true
            }
        }
        return false
    }

    static func set(session: Session, body: [String: Any]) async -> Bool {
        if session.provider == .codex, session.existsOnServer, let endpoint = session.endpoint,
            let requestId = ChatGoalRequestStore.begin(sessionId: session.id, mutating: true)
        {
            let result = await HTTPClient.post(
                endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/goal", body: body)
            if ChatGoalRequestStore.finish(requestId, sessionId: session.id), !Task.isCancelled,
                let (data, response) = result, response.statusCode == 200,
                let value = try? JSONDecoder().decode(ChatGoalResponse.self, from: data)
            {
                SessionActions.setGoal(value.goal, for: session)
                return true
            }
        }
        return false
    }

    static func clear(session: Session) async -> Bool {
        if session.provider == .codex, session.existsOnServer, let endpoint = session.endpoint,
            let requestId = ChatGoalRequestStore.begin(sessionId: session.id, mutating: true)
        {
            let result = await HTTPClient.delete(
                endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/goal", timeout: 10)
            if ChatGoalRequestStore.finish(requestId, sessionId: session.id), !Task.isCancelled,
                let (_, response) = result, response.statusCode == 200
            {
                SessionActions.setGoal(nil, for: session)
                return true
            }
        }
        return false
    }
}

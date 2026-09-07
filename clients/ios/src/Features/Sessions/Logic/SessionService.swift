import Foundation

enum SessionService {
    static func archive(session: Session, archived: Bool) async -> Bool {
        let connectionKey = session.connectionKey
        if session.provider == .codex && session.existsOnServer {
            if let endpoint = session.endpoint,
                let (_, response) = await HTTPClient.post(
                    endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/archive", body: ["archived": archived]
                ), response.statusCode == 200, session.connectionKey == connectionKey
            {
                SessionActions.setArchived(session, archived)
                return true
            }
            return false
        }
        SessionActions.setArchived(session, archived)
        return true
    }

    static func rename(session: Session, title: String) async -> Bool {
        let connectionKey = session.connectionKey
        if session.provider == .codex && session.existsOnServer {
            if let endpoint = session.endpoint,
                let (_, response) = await HTTPClient.post(
                    endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/name", body: ["name": title]),
                response.statusCode == 200, session.connectionKey == connectionKey
            {
                SessionActions.rename(session, title: title)
                return true
            }
            return false
        }
        SessionActions.rename(session, title: title)
        return true
    }

    static func generateTitleAndSymbol(
        endpoint: Endpoint,
        sessionId: UUID,
        path: String
    ) async -> (title: String, symbol: String)? {
        let result = await HTTPClient.post(
            endpoint: endpoint,
            path: "/sessions/\(sessionId.uuidString)/title",
            body: ["path": path],
            timeout: 30
        )
        if let (data, response) = result, response.statusCode == 200,
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let title = obj["title"] as? String,
            let symbol = obj["symbol"] as? String
        {
            return (title, symbol)
        }
        return nil
    }
}

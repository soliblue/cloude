import Foundation

enum SessionService {
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

    static func skills(endpoint: Endpoint, sessionId: UUID, path: String) async -> [Skill]? {
        let result = await HTTPClient.get(
            endpoint: endpoint,
            path: "/sessions/\(sessionId.uuidString)/skills",
            query: ["path": path],
            timeout: 5
        )
        if let (data, response) = result, response.statusCode == 200,
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entries = obj["entries"] as? [[String: String]]
        {
            return entries.map { Skill(name: $0["name"] ?? "", description: $0["description"] ?? "") }
        }
        return nil
    }

    static func agents(endpoint: Endpoint, sessionId: UUID, path: String) async -> [Agent]? {
        let result = await HTTPClient.get(
            endpoint: endpoint,
            path: "/sessions/\(sessionId.uuidString)/agents",
            query: ["path": path],
            timeout: 5
        )
        if let (data, response) = result, response.statusCode == 200,
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entries = obj["entries"] as? [[String: String]]
        {
            return entries.map { Agent(name: $0["name"] ?? "", description: $0["description"] ?? "") }
        }
        return nil
    }
}

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
}

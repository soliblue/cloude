import Foundation

enum SessionManifestService {
    static func fetch(endpoint: Endpoint, sessionId: UUID, path: String) async -> SessionManifestDTO? {
        if let (data, response) = await HTTPClient.get(
            endpoint: endpoint,
            path: "/sessions/\(sessionId.uuidString)/manifest",
            query: ["path": path],
            timeout: 5
        ), response.statusCode == 200 {
            return try? JSONDecoder().decode(SessionManifestDTO.self, from: data)
        }
        return nil
    }
}

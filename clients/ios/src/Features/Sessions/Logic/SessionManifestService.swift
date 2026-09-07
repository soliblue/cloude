import Foundation

enum SessionManifestService {
    @MainActor static func invalidate(sessionId: UUID) {
        SessionManifestStore.shared.set(skills: [], agents: [], transcription: false, for: sessionId)
    }

    static func fetch(
        endpoint: Endpoint, sessionId: UUID, path: String, provider: ChatProvider = .claude
    ) async -> SessionManifestDTO? {
        if let (data, response) = await HTTPClient.get(
            endpoint: endpoint,
            path: "/sessions/\(sessionId.uuidString)/manifest",
            query: ["path": path, "provider": provider.rawValue],
            timeout: 5
        ), response.statusCode == 200 {
            return try? JSONDecoder().decode(SessionManifestDTO.self, from: data)
        }
        return nil
    }
}

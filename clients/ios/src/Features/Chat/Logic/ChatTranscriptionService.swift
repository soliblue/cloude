import Foundation

enum ChatTranscriptionService {
    static func transcribe(endpoint: Endpoint, sessionId: UUID, audio: Data) async -> String? {
        if let (data, response) = await HTTPClient.post(
            endpoint: endpoint,
            path: "/sessions/\(sessionId.uuidString)/transcribe",
            body: ["audio": audio.base64EncodedString()],
            timeout: 60
        ), response.statusCode == 200,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let text = object["text"] as? String
        {
            return text
        }
        return nil
    }
}

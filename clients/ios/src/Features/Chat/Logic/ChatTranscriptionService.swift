import Foundation

@MainActor enum ChatTranscriptionService {
    static func transcribe(endpoint: Endpoint, sessionId: UUID, audio: Data) async -> String? {
        let scope = endpoint.cacheId
        if !Task.isCancelled, ChatLocalTranscription.available,
            let text = await ChatLocalTranscription().transcribe(audio: audio),
            !text.isEmpty, !Task.isCancelled, endpoint.cacheId == scope
        {
            return text
        }
        if !Task.isCancelled, endpoint.cacheId == scope,
            let (data, response) = await HTTPClient.post(
                endpoint: endpoint,
                path: "/sessions/\(sessionId.uuidString)/transcribe",
                body: ["audio": audio.base64EncodedString()],
                timeout: 60
            ), !Task.isCancelled, endpoint.cacheId == scope, response.statusCode == 200,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let text = object["text"] as? String
        {
            return text
        }
        return nil
    }
}

import Foundation

@main struct ChatTranscriptionTests {
    @MainActor static func main() async {
        let endpoint = Endpoint()
        let sessionId = UUID()
        let audio = Data([0, 1, 2, 3, 255])
        ChatLocalTranscription.result = "Recognized on device"
        let local = await ChatTranscriptionService.transcribe(endpoint: endpoint, sessionId: sessionId, audio: audio)
        precondition(local == "Recognized on device" && ChatLocalTranscription.calls == 1 && HTTPClient.calls == 0)
        ChatLocalTranscription.result = nil
        HTTPClient.result = (
            Data(#"{"text":"Recognized by remote host"}"#.utf8),
            HTTPURLResponse(
                url: URL(string: "https://host.local")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
        let fallback = await ChatTranscriptionService.transcribe(endpoint: endpoint, sessionId: sessionId, audio: audio)
        precondition(fallback == "Recognized by remote host" && HTTPClient.lastEndpoint == endpoint.id)
        precondition(HTTPClient.path == "/sessions/\(sessionId.uuidString)/transcribe" && HTTPClient.body.count == 1)
        precondition(Data(base64Encoded: HTTPClient.body["audio"] as! String) == audio)
        ChatLocalTranscription.available = false
        let localCalls = ChatLocalTranscription.calls
        HTTPClient.result = nil
        let unavailable = await ChatTranscriptionService.transcribe(
            endpoint: endpoint, sessionId: sessionId, audio: audio)
        precondition(unavailable == nil && ChatLocalTranscription.calls == localCalls)
        ChatLocalTranscription.available = true
        ChatLocalTranscription.result = nil
        ChatLocalTranscription.beforeReturn = { endpoint.cacheId = UUID() }
        let beforeChangedHost = HTTPClient.calls
        _ = await ChatTranscriptionService.transcribe(endpoint: endpoint, sessionId: sessionId, audio: audio)
        precondition(HTTPClient.calls == beforeChangedHost, "Local fallback must not upload to a changed host")
        ChatLocalTranscription.beforeReturn = nil
        let canceled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await ChatTranscriptionService.transcribe(endpoint: endpoint, sessionId: sessionId, audio: audio)
        }
        let canceledResult = await canceled.value
        precondition(canceledResult == nil && HTTPClient.calls == beforeChangedHost)
        print(
            "PASS on-device transcription bypasses network; fallback targets only configured daemon with audio; no model/API-key request; errors propagate as unavailable"
        )
    }
}

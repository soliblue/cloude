import Foundation
import SwiftData

@main struct SessionConnectionTests {
    @MainActor static func main() async {
        let endpoint = Endpoint()
        let session = Session(endpoint: endpoint, path: "/repo", title: "Saved title")
        session.existsOnServer = true
        session.codexThreadId = "native-thread"
        session.hasGit = false
        session.isStreaming = true
        session.followsRemote = true
        session.remoteIsRunning = true
        session.needsAttention = true
        session.remoteHistoryETag = "old-etag"
        session.codexProjectId = "project"
        session.modelRaw = "gpt-5.5"
        session.provider = .codex
        let key = session.connectionKey
        SessionActions.connectionChanged(for: session)
        endpoint.connectionRevision = UUID()
        precondition(key != session.connectionKey)
        precondition(
            session.title == "Saved title" && session.path == "/repo" && session.existsOnServer
                && session.codexThreadId == "native-thread" && session.modelRaw == "gpt-5.5")
        precondition(
            session.hasGit && !session.isStreaming && !session.followsRemote && !session.remoteIsRunning
                && !session.needsAttention
                && session.remoteHistoryETag == nil && session.codexProjectId == nil)
        ChatAccountStore.shared.accounts[endpoint.id] = ChatAccountSnapshot(
            email: "old@example.com", plan: "plus", isSubscription: true, isSignedIn: true, windows: [])
        HTTPClient.responses["/codex/account"] = HTTPClient.response([
            "account": ["type": "chatgpt", "email": "old@example.com"]
        ])
        HTTPClient.responses["/codex/limits"] = HTTPClient.response([:])
        HTTPClient.beforeGet = { path in
            if path == "/codex/account" { ChatAccountService.invalidate(endpointId: endpoint.id) }
        }
        await ChatAccountService.refresh(endpoint: endpoint)
        precondition(
            ChatAccountStore.shared.accounts[endpoint.id] == nil
                && ChatAccountStore.shared.generations[endpoint.id] == nil
                && !ChatAccountStore.shared.loading.contains(endpoint.id))
        HTTPClient.responses["/codex/models"] = HTTPClient.response([
            "data": [
                [
                    "id": "old", "model": "old", "displayName": "Old model", "isDefault": true,
                    "supportedReasoningEfforts": [], "defaultReasoningEffort": "high",
                ]
            ]
        ])
        HTTPClient.beforeGet = { _ in ChatModelService.invalidate(sessionId: session.id) }
        await ChatModelService.refresh(session: session)
        precondition(
            ChatModelCatalog.shared.options[session.id] == nil && ChatModelCatalog.shared.generations[session.id] == nil
                && !ChatModelCatalog.shared.loading.contains(session.id))
        SessionManifestStore.shared.set(skills: [], agents: [], transcription: true, for: session.id)
        SessionManifestService.invalidate(sessionId: session.id)
        precondition(!SessionManifestStore.shared.transcriptionReady(for: session.id))
        HTTPClient.beforeGet = nil
        await ChatModelService.refresh(session: session)
        precondition(ChatModelCatalog.shared.options[session.id]?.first?.model == "old")
        ChatModelService.invalidate(sessionId: session.id)
        precondition(ChatModelCatalog.shared.options[session.id] == nil)
        print(
            "PASS connection scope rotation, saved remote identity preservation, live-state reset, account/model cache clearing and stale response rejection, manifest reset"
        )
    }
}

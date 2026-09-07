import Foundation
import SwiftData

@main struct SessionLoginTests {
    @MainActor static func main() async {
        let endpoint = Endpoint()
        let other = Endpoint()
        let store = SessionLoginStore()
        HTTPClient.set(["status": "idle"])
        await SessionLoginService.refresh(endpoint: endpoint, store: store)
        precondition(store.snapshot?.status == "idle" && HTTPClient.posts == 0)
        HTTPClient.set([
            "status": "pending", "loginId": "login1", "userCode": "ABCD-EFGH",
            "verificationUrl": "https://auth.openai.com/codex/device",
        ])
        HTTPClient.beforePost = {
            await SessionLoginService.start(endpoint: endpoint, store: store)
            await SessionLoginService.refresh(endpoint: endpoint, store: store)
        }
        await SessionLoginService.start(endpoint: endpoint, store: store)
        HTTPClient.beforePost = nil
        precondition(HTTPClient.posts == 1 && HTTPClient.body["type"] as? String == "chatgptDeviceCode")
        precondition(store.isPending && store.snapshot?.verificationURL?.scheme == "https")
        HTTPClient.response = nil
        await SessionLoginService.refresh(endpoint: endpoint, store: store)
        precondition(store.isPending && store.error != nil && !store.isLoading)
        precondition(URLProtocol.registerClass(SessionLoginURLProtocol.self))
        await SessionLoginService.cancel(endpoint: endpoint, store: store)
        precondition(store.snapshot?.status == "canceled" && store.snapshot?.userCode == nil)
        precondition(SessionLoginURLProtocol.captured?.httpMethod == "DELETE")
        precondition(SessionLoginURLProtocol.captured?.value(forHTTPHeaderField: "Authorization") == "Bearer test")
        URLProtocol.unregisterClass(SessionLoginURLProtocol.self)
        HTTPClient.set(["status": "pending", "loginId": "stale"])
        HTTPClient.beforeGet = {
            HTTPClient.set(["status": "completed", "loginId": "new"])
            await SessionLoginService.start(endpoint: endpoint, store: store)
        }
        await SessionLoginService.refresh(endpoint: endpoint, store: store)
        HTTPClient.beforeGet = nil
        precondition(store.completionId == "new")
        HTTPClient.set(["status": "pending", "loginId": "wrong-machine"])
        HTTPClient.beforeGet = {
            HTTPClient.beforeGet = nil
            HTTPClient.set(["status": "idle"])
            await SessionLoginService.refresh(endpoint: other, store: store)
        }
        await SessionLoginService.refresh(endpoint: endpoint, store: store)
        precondition(store.endpointId == other.id && store.snapshot?.status == "idle")
        HTTPClient.set(["status": "pending"])
        HTTPClient.beforeGet = { store.invalidate() }
        await SessionLoginService.refresh(endpoint: other, store: store)
        HTTPClient.beforeGet = nil
        precondition(store.snapshot?.status == "idle" && !store.isLoading)
        HTTPClient.set(["status": "failed", "error": "Device sign-in unavailable"], status: 502)
        await SessionLoginService.start(endpoint: other, store: store)
        precondition(store.error == "Device sign-in unavailable" && !store.isMutating)
        HTTPClient.set(["status": "pending", "loginId": "retry"])
        await SessionLoginService.start(endpoint: other, store: store)
        precondition(store.isPending && store.error == nil)
        for url in [
            "http://auth.openai.com/codex/device", "https://auth.openai.com.evil.test/codex/device",
            "https://example.com", "javascript:alert(1)", "file:///tmp/code", "https://user:pass@host.test",
            "https:///",
            "data:text/plain,test",
        ] {
            let value = SessionLoginSnapshot(
                status: "pending", loginId: nil, userCode: nil, verificationUrl: url, error: nil)
            precondition(value.verificationURL == nil)
        }
        let terminal = SessionLoginSnapshot(
            status: "completed", loginId: nil, userCode: nil, verificationUrl: "https://auth.openai.com", error: nil)
        precondition(terminal.verificationURL == nil)
        let container = try! ModelContainer(
            for: Session.self, Endpoint.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let a = Session(endpoint: endpoint)
        a.provider = .codex
        let b = Session(endpoint: other)
        b.provider = .codex
        let c = Session(endpoint: endpoint)
        c.provider = .claude
        for session in [a, b, c] { container.mainContext.insert(session) }
        await SessionLoginService.refreshSignedIn(endpoint: endpoint, context: container.mainContext)
        precondition(ChatAccountService.refreshed == [endpoint.id] && ChatModelService.refreshed == [a.id])
        print(
            "PASS device sign-in, duplicate starts, signed cancellation, offline recovery, stale poll/retry/endpoint/disappearance, URL validation and scoped account/model refresh"
        )
    }
}

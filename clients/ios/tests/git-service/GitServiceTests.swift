import Foundation
import SwiftData

@main struct GitServiceTests {
    @MainActor static func main() async throws {
        let container = try ModelContainer(
            for: GitStatus.self, GitChange.self, GitCommit.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let session = Session()
        session.endpoint = Endpoint(host: "fixture.invalid")
        session.path = "/old"
        await GitService.refresh(session: session, context: container.mainContext)
        precondition(!session.hasGit)
        var held: [(String, CheckedContinuation<(Data, HTTPURLResponse)?, Never>)] = []
        func response(_ path: String, _ branch: String) -> (Data, HTTPURLResponse) {
            let value: [String: Any] =
                path.hasSuffix("/status")
                ? ["branch": branch, "ahead": 0, "behind": 0, "changes": []]
                : [
                    "commits": [
                        ["sha": branch, "subject": branch, "author": "Fixture", "date": "2026-09-06T10:00:00Z"]
                    ]
                ]
            return (
                try! JSONSerialization.data(withJSONObject: value),
                HTTPURLResponse(
                    url: URL(string: "https://fixture.invalid")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }
        HTTPClient.handler = { path, query in
            if query["path"] == "/old" { return await withCheckedContinuation { held.append((path, $0)) } }
            return response(path, "new")
        }
        let first = Task { await GitService.refresh(session: session, context: container.mainContext) }
        for _ in 0..<1000 where held.count < 2 { await Task.yield() }
        precondition(held.count == 2)
        session.path = "/new"
        first.cancel()
        let second = Task { await GitService.refresh(session: session, context: container.mainContext) }
        for _ in 0..<10 { await Task.yield() }
        for (path, continuation) in held { continuation.resume(returning: response(path, "old")) }
        held.removeAll()
        await first.value
        await second.value
        precondition(session.hasGit)
        precondition(try! container.mainContext.fetch(FetchDescriptor<GitStatus>()).first?.branch == "new")
        precondition(try! container.mainContext.fetch(FetchDescriptor<GitCommit>()).map(\.sha) == ["new"])
        HTTPClient.handler = { path, _ in await withCheckedContinuation { held.append((path, $0)) } }
        let page = Task { await GitService.loadMore(session: session, count: 1, context: container.mainContext) }
        for _ in 0..<1000 where held.isEmpty { await Task.yield() }
        precondition(held.count == 1)
        session.path = "/other"
        held[0].1.resume(returning: response(held[0].0, "wrong-page"))
        let count = await page.value
        precondition(count == nil)
        precondition(try! container.mainContext.fetch(FetchDescriptor<GitCommit>()).map(\.sha) == ["new"])
        held.removeAll()
        let revisedPage = Task { await GitService.loadMore(session: session, count: 1, context: container.mainContext) }
        for _ in 0..<1000 where held.isEmpty { await Task.yield() }
        precondition(held.count == 1)
        session.endpoint?.connectionRevision = UUID()
        held[0].1.resume(returning: response(held[0].0, "old-server"))
        let revisedCount = await revisedPage.value
        precondition(revisedCount == nil)
        precondition(try! container.mainContext.fetch(FetchDescriptor<GitCommit>()).map(\.sha) == ["new"])
        HTTPClient.handler = { _, _ in nil }
        await GitService.refresh(session: session, context: container.mainContext)
        precondition(session.hasGit)
        precondition(try! container.mainContext.fetch(FetchDescriptor<GitCommit>()).map(\.sha) == ["new"])
        print(
            "Git service: offline state preservation, source-change fencing, canceled caller coalescing and stale page rejection passed"
        )
    }
}

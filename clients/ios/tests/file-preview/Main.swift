import Foundation

@main
struct Main {
    static func main() async throws {
        let endpoint = Endpoint()
        let scope = endpoint.cacheId
        let session = Session(endpoint: endpoint)
        let node = FileNodeDTO(
            name: "artifact.txt", path: "/work/artifact.txt", isDirectory: false, size: nil, modifiedAt: nil,
            mimeType: "text/plain")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        await FileCache.shared.store(Data("saved artifact".utf8), endpoint: scope, path: node.path, category: "files")
        for status in [401, 404, 503] {
            let responseFile = directory.appendingPathComponent("response-\(status)")
            try Data("server error".utf8).write(to: responseFile)
            HTTPClient.response = (
                responseFile,
                HTTPURLResponse(
                    url: URL(string: "http://fixture")!, statusCode: status, httpVersion: nil, headerFields: nil)!
            )
            let preview = await FilePreviewService.load(session: session, node: node)
            precondition(preview?.data == Data("saved artifact".utf8) && preview?.isCached == true)
            precondition(!FileManager.default.fileExists(atPath: responseFile.path))
        }
        HTTPClient.response = nil
        let offline = await FilePreviewService.load(session: session, node: node)
        precondition(offline?.data == Data("saved artifact".utf8) && offline?.isCached == true)
        let fresh = directory.appendingPathComponent("fresh")
        try Data("updated artifact".utf8).write(to: fresh)
        HTTPClient.response = (
            fresh,
            HTTPURLResponse(url: URL(string: "http://fixture")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
        let updated = await FilePreviewService.load(session: session, node: node)
        precondition(updated?.data == Data("updated artifact".utf8) && updated?.isCached == false)
        HTTPClient.response = nil
        HTTPClient.beforeDownload = { endpoint.cacheId = UUID() }
        let changed = await FilePreviewService.load(session: session, node: node)
        precondition(changed == nil)
        endpoint.cacheId = scope
        var release: CheckedContinuation<Void, Never>?
        HTTPClient.beforeDownload = { await withCheckedContinuation { release = $0 } }
        let task = Task { await FilePreviewService.load(session: session, node: node) }
        while release == nil { await Task.yield() }
        task.cancel()
        release?.resume()
        let canceled = await task.value
        precondition(canceled == nil)
        HTTPClient.beforeDownload = nil
        await FileCache.shared.remove(endpoint: scope)
        let missing = await FilePreviewService.load(session: session, node: node)
        precondition(missing == nil)
        print(
            "PASS saved previews survive HTTP401/404/503 and offline reload, refresh fresh content, and fence changed endpoints and cancellation"
        )
    }
}

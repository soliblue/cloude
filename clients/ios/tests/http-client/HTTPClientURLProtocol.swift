import Foundation
import os

final class HTTPClientURLProtocol: URLProtocol, @unchecked Sendable {
    static let pending = OSAllocatedUnfairLock<HTTPClientURLProtocol?>(initialState: nil)
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "afto-http.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer subscription-fixture")
        if request.url?.path == "/delete" {
            precondition(request.httpMethod == "DELETE")
            precondition(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        }
        if request.url?.path == "/hold" { Self.pending.withLock { $0 = self } } else { finish() }
    }
    func finish() {
        client?.urlProtocol(
            self,
            didReceive: HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["X-Daemon-Capabilities": "codex, gitWorktrees"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("response".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { Self.pending.withLock { if $0 === self { $0 = nil } } }
}

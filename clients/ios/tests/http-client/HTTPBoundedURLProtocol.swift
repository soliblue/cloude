import Foundation
import os

final class HTTPBoundedURLProtocol: URLProtocol, @unchecked Sendable {
    static let pending = OSAllocatedUnfairLock<HTTPBoundedURLProtocol?>(initialState: nil)
    static let started = OSAllocatedUnfairLock<[URLRequest]>(initialState: [])
    static let stopped = OSAllocatedUnfairLock<Int>(initialState: 0)

    override class func canInit(with request: URLRequest) -> Bool {
        ["afto-bounded.invalid", "redirect-bounded.invalid"].contains(request.url?.host ?? "")
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.started.withLock { $0.append(request) }
        precondition(request.url?.host == "afto-bounded.invalid", "redirect followed")
        precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer subscription-fixture")
        precondition(request.value(forHTTPHeaderField: "Range") != nil)
        if request.url?.lastPathComponent == "hold" {
            Self.pending.withLock { $0 = self }
        } else if request.url?.lastPathComponent == "redirect" {
            client?.urlProtocol(
                self, wasRedirectedTo: URLRequest(url: URL(string: "https://redirect-bounded.invalid/secret")!),
                redirectResponse: HTTPURLResponse(
                    url: request.url!, statusCode: 302, httpVersion: nil,
                    headerFields: ["Location": "https://redirect-bounded.invalid/secret"])!)
        } else {
            if request.url?.lastPathComponent == "overflow-held" { Self.pending.withLock { $0 = self } }
            finish()
        }
    }

    func finish() {
        let mode = request.url!.lastPathComponent
        var headers = ["X-Daemon-Capabilities": "codex, codexTerminal"]
        if mode == "exact206" { headers["Content-Range"] = "bytes 0-4/5" }
        if ["exact206", "exact200"].contains(mode) { headers["Content-Length"] = "5" }
        if mode == "header-overflow" { headers["Content-Length"] = "6" }
        if mode == "misleading" { headers["Content-Length"] = "1" }
        if mode == "empty" { headers["Content-Length"] = "0" }
        client?.urlProtocol(
            self,
            didReceive: HTTPURLResponse(
                url: request.url!, statusCode: mode == "exact206" ? 206 : 200, httpVersion: nil, headerFields: headers)!,
            cacheStoragePolicy: .notAllowed)
        if mode != "empty" {
            client?.urlProtocol(self, didLoad: Data([1, 2]))
            client?.urlProtocol(self, didLoad: Data([3, 4, 5]))
            if ["overflow", "overflow-held", "misleading", "header-overflow"].contains(mode) {
                client?.urlProtocol(
                    self, didLoad: mode == "overflow-held" ? Data(repeating: 6, count: 131_072) : Data([6]))
            }
        }
        if mode != "overflow-held" { client?.urlProtocolDidFinishLoading(self) }
    }

    override func stopLoading() {
        Self.stopped.withLock { $0 += 1 }
        Self.pending.withLock { if $0 === self { $0 = nil } }
    }
}

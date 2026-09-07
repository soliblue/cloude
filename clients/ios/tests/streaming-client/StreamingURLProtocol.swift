import Foundation
import os

final class StreamingURLProtocol: URLProtocol, @unchecked Sendable {
    static let canceled = OSAllocatedUnfairLock(initialState: false)
    override class func canInit(with request: URLRequest) -> Bool { request.url?.scheme == "aftostream" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        precondition(request.value(forHTTPHeaderField: "Authorization") == "Bearer subscription-fixture")
        let path = request.url!.path
        client?.urlProtocol(
            self,
            didReceive: HTTPURLResponse(
                url: request.url!, statusCode: path == "/denied" ? 401 : 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/x-ndjson"])!, cacheStoragePolicy: .notAllowed)
        if path == "/hold" {
            client?.urlProtocol(self, didLoad: Data("initial\n".utf8))
        } else {
            let text =
                path == "/denied"
                ? "denied" : (0..<20000).map { "{\"index\":\($0),\"text\":\"é日本語\"}" }.joined(separator: "\n")
            let data = Data(text.utf8)
            for offset in stride(from: 0, to: data.count, by: 617) {
                client?.urlProtocol(self, didLoad: data.subdata(in: offset..<min(offset + 617, data.count)))
            }
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {
        if request.url?.path == "/hold" { Self.canceled.withLock { $0 = true } }
    }
}

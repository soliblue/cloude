import Foundation
import Network

struct HTTPResponse {
    enum Body {
        case buffered(Data)
        case streamed((NWConnection) -> Void)
    }

    let status: Int
    let body: Body
    let contentType: String
    let extraHeaders: [String: String]

    init(
        status: Int,
        body: Data,
        contentType: String = "application/json",
        extraHeaders: [String: String] = [:]
    ) {
        self.status = status
        self.body = .buffered(body)
        self.contentType = contentType
        self.extraHeaders = extraHeaders
    }

    static func json(_ status: Int, _ object: Any) -> HTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
        return HTTPResponse(status: status, body: data)
    }

    static func text(_ status: Int, _ string: String) -> HTTPResponse {
        HTTPResponse(status: status, body: Data(string.utf8), contentType: "text/plain; charset=utf-8")
    }

    static func stream(
        status: Int = 200,
        contentType: String = "application/x-ndjson",
        extraHeaders: [String: String] = [:],
        streamer: @escaping (NWConnection) -> Void
    ) -> HTTPResponse {
        HTTPResponse(
            status: status,
            body: .streamed(streamer),
            contentType: contentType,
            extraHeaders: extraHeaders
        )
    }

    private init(status: Int, body: Body, contentType: String, extraHeaders: [String: String]) {
        self.status = status
        self.body = body
        self.contentType = contentType
        self.extraHeaders = extraHeaders
    }

    func serializeHeaders() -> Data {
        var text = "HTTP/1.1 \(status) \(statusText)\r\n"
        text += "Content-Type: \(contentType)\r\n"
        if case .buffered(let data) = body {
            text += "Content-Length: \(data.count)\r\n"
        }
        for (key, value) in extraHeaders {
            text += "\(key): \(value)\r\n"
        }
        text += "Connection: close\r\n\r\n"
        return Data(text.utf8)
    }

    func serialize() -> Data {
        var data = serializeHeaders()
        if case .buffered(let payload) = body { data.append(payload) }
        return data
    }

    private var statusText: String {
        switch status {
        case 200: return "OK"
        case 206: return "Partial Content"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        default: return "Error"
        }
    }
}

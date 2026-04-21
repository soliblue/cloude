import Foundation

struct HTTPResponse {
    let status: Int
    let body: Data
    let contentType: String
    let extraHeaders: [String: String]

    init(status: Int, body: Data, contentType: String = "application/json", extraHeaders: [String: String] = [:]) {
        self.status = status
        self.body = body
        self.contentType = contentType
        self.extraHeaders = extraHeaders
    }

    static func json(_ status: Int, _ object: Any) -> HTTPResponse {
        let data = try! JSONSerialization.data(withJSONObject: object)
        return HTTPResponse(status: status, body: data)
    }

    static func text(_ status: Int, _ string: String) -> HTTPResponse {
        HTTPResponse(status: status, body: Data(string.utf8), contentType: "text/plain; charset=utf-8")
    }

    func serialize() -> Data {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 206: statusText = "Partial Content"
        case 400: statusText = "Bad Request"
        case 401: statusText = "Unauthorized"
        case 403: statusText = "Forbidden"
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        default: statusText = "Error"
        }
        var text = "HTTP/1.1 \(status) \(statusText)\r\n"
        text += "Content-Type: \(contentType)\r\n"
        text += "Content-Length: \(body.count)\r\n"
        for (key, value) in extraHeaders {
            text += "\(key): \(value)\r\n"
        }
        text += "Connection: close\r\n\r\n"
        var data = Data(text.utf8)
        data.append(body)
        return data
    }
}

import Foundation

struct HTTPResponse {
    let status: Int
    let body: Data
    let contentType: String

    init(status: Int, body: Data, contentType: String = "application/json") {
        self.status = status
        self.body = body
        self.contentType = contentType
    }

    static func json(_ status: Int, _ object: [String: Any]) -> HTTPResponse {
        let data = try! JSONSerialization.data(withJSONObject: object)
        return HTTPResponse(status: status, body: data)
    }

    func serialize() -> Data {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 401: statusText = "Unauthorized"
        case 404: statusText = "Not Found"
        default: statusText = "Error"
        }
        var text = "HTTP/1.1 \(status) \(statusText)\r\n"
        text += "Content-Type: \(contentType)\r\n"
        text += "Content-Length: \(body.count)\r\n"
        text += "Connection: close\r\n\r\n"
        var data = Data(text.utf8)
        data.append(body)
        return data
    }
}

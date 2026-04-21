import Foundation

struct HTTPRequest {
    let method: String
    let path: String
    let query: [String: String]
    let headers: [String: String]
    let body: Data

    struct ParsedHead {
        let method: String
        let path: String
        let query: [String: String]
        let headers: [String: String]
        let headerEnd: Int
        var contentLength: Int { Int(headers["content-length"] ?? "") ?? 0 }
    }

    static func parseHead(_ data: Data) -> ParsedHead? {
        if let headerEnd = data.range(of: Data([13, 10, 13, 10])),
            let headerText = String(data: data.subdata(in: 0..<headerEnd.lowerBound), encoding: .utf8)
        {
            let lines = headerText.components(separatedBy: "\r\n")
            if let requestLine = lines.first {
                let parts = requestLine.components(separatedBy: " ")
                if parts.count >= 2 {
                    var headers: [String: String] = [:]
                    for line in lines.dropFirst() {
                        if let colon = line.firstIndex(of: ":") {
                            headers[String(line[..<colon]).lowercased()] =
                                line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                        }
                    }
                    let (path, query) = RouteMatcher.split(parts[1])
                    return ParsedHead(
                        method: parts[0], path: path, query: query, headers: headers,
                        headerEnd: headerEnd.upperBound
                    )
                }
            }
        }
        return nil
    }

    init(head: ParsedHead, body: Data) {
        self.method = head.method
        self.path = head.path
        self.query = head.query
        self.headers = head.headers
        self.body = body
    }
}

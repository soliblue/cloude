import Foundation

struct HTTPRequest {
    let method: String
    let path: String
    let query: [String: String]
    let headers: [String: String]
    let body: Data
    let cancellation: HTTPRequestCancellation

    struct ParsedHead {
        let method: String
        let path: String
        let query: [String: String]
        let headers: [String: String]
        let headerEnd: Int
        let contentLength: Int
    }

    static func parseHead(_ data: Data) -> ParsedHead? {
        if let headerEnd = data.range(of: Data([13, 10, 13, 10])),
            let headerText = String(data: data.subdata(in: 0..<headerEnd.lowerBound), encoding: .utf8)
        {
            let lines = headerText.components(separatedBy: "\r\n")
            if let requestLine = lines.first {
                let parts = requestLine.components(separatedBy: " ")
                if parts.count == 3, ["HTTP/1.0", "HTTP/1.1"].contains(parts[2]),
                    validToken(parts[0]), parts[1].hasPrefix("/"),
                    parts[1].utf8.allSatisfy({ $0 > 32 && $0 != 127 })
                {
                    var headers: [String: String] = [:]
                    for line in lines.dropFirst() {
                        if let colon = line.firstIndex(of: ":"), validToken(String(line[..<colon])),
                            line.utf8.allSatisfy({ $0 == 9 || ($0 >= 32 && $0 != 127) })
                        {
                            let name = String(line[..<colon]).lowercased()
                            if headers[name] != nil { return nil }
                            headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                        } else {
                            return nil
                        }
                    }
                    if headers["transfer-encoding"] == nil,
                        headers["content-length"] == nil
                            || headers["content-length"]!.utf8.allSatisfy({ (48...57).contains($0) }),
                        let contentLength = Int(headers["content-length"] ?? "0"), contentLength >= 0
                    {
                        let (path, query) = RouteMatcher.split(parts[1])
                        return ParsedHead(
                            method: parts[0], path: path, query: query, headers: headers,
                            headerEnd: headerEnd.upperBound, contentLength: contentLength
                        )
                    }
                }
            }
        }
        return nil
    }

    private static func validToken(_ value: String) -> Bool {
        !value.isEmpty
            && value.utf8.allSatisfy {
                (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
                    || "!#$%&'*+-.^_`|~".utf8.contains($0)
            }
    }

    init(head: ParsedHead, body: Data, cancellation: HTTPRequestCancellation = HTTPRequestCancellation()) {
        self.method = head.method
        self.path = head.path
        self.query = head.query
        self.headers = head.headers
        self.body = body
        self.cancellation = cancellation
    }
}

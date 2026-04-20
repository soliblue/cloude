import Foundation

struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data

    static func parse(_ data: Data) -> HTTPRequest? {
        if let headerEnd = data.range(of: Data([13, 10, 13, 10])),
           let headerText = String(data: data.subdata(in: 0..<headerEnd.lowerBound), encoding: .utf8) {
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
                    return HTTPRequest(method: parts[0], path: parts[1], headers: headers, body: data.subdata(in: headerEnd.upperBound..<data.count))
                }
            }
        }
        return nil
    }
}

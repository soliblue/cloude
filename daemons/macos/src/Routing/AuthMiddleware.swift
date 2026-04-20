import Foundation

enum AuthMiddleware {
    static func isAuthorized(_ request: HTTPRequest) -> Bool {
        if let header = request.headers["authorization"], header.hasPrefix("Bearer ") {
            let presented = Array(header.dropFirst("Bearer ".count).utf8)
            let expected = Array(DaemonAuth.token.utf8)
            if presented.count == expected.count {
                var diff: UInt8 = 0
                for i in 0..<presented.count { diff |= presented[i] ^ expected[i] }
                return diff == 0
            }
        }
        return false
    }
}

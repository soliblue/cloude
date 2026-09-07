import Foundation

struct TerminalInput {
    let writerId: UUID
    let sequence: Int
    let data: Data
    var body: [String: Any] {
        ["writerId": writerId.uuidString, "sequence": sequence, "deltaBase64": data.base64EncodedString()]
    }
}

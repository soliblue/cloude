import Foundation

struct TerminalEvent: Decodable {
    let type: String
    let seq: Int?
    let deltaBase64: String?
    let firstSeq: Int?
    let requestedAfterSeq: Int?
}

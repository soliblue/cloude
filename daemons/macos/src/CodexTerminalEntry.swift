import Foundation

struct CodexTerminalEntry {
    let admission: UUID
    let sessionId: String
    let processId: String
    let startKey: String
    let cwd: String
    let createdAt: Date
    var rows: Int
    var cols: Int
    var events: [[String: Any]] = []
    var input: [String: CodexTerminalInput] = [:]
    var subscribers: [String: ([String: Any]?, Bool) -> Void] = [:]
    var outputBytes = 0
    var pendingInputs = 0
    var ended = false
    var exitCode: Int?
    var error: String?
    var endedAt: Date?
    var nextSeq = 0
}

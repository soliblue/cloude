import Foundation

struct CodexTerminalStart {
    let cwd: String
    let rows: Int
    let cols: Int
    let operation: CodexTerminalRequest<[String: Any]>
    var processId: String?
}

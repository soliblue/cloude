import Foundation

struct CodexTerminalInput {
    let sequence: Int
    let fingerprint: Data
    let operation: CodexTerminalRequest<Bool>
}

import Foundation
import CloudeShared

struct WindowRuntimeContext {
    let conversation: Conversation?
    let environmentId: UUID?
    let environment: ServerEnvironment?
    let connection: EnvironmentConnection?
    let workingDirectory: String?

    var symbol: String? {
        connection?.symbol ?? environment?.symbol
    }
}

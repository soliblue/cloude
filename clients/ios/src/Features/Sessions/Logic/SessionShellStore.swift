import Foundation
import Observation

@MainActor @Observable final class SessionShellStore {
    var command = ""
    var error: String?

    func canRun(session: Session) -> Bool {
        session.provider == .codex && session.isConfigured && !session.isStreaming && !session.remoteIsRunning
            && session.endpoint?.capabilities?.contains("codexShell") == true
            && ChatShellCommand(rawValue: command).isValid
    }
}

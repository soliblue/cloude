import Combine
import Foundation
import CloudeShared

extension Connection {
    func handleAuthResult(_ store: ConnectionStore, success: Bool, errorMessage: String?) {
        phase = success ? .authenticated : .connected
        if success {
            resumeInterruptedSessions()
            git.sendNextStatusIfReady()
            store.events.send(.authenticated(environmentId: environmentId))
        } else {
            lastError = errorMessage ?? "Authentication failed"
        }
    }

    func handleError(_ errorMessage: String) {
        lastError = errorMessage
        files.failPendingOperations(errorMessage)
        git.failPendingOperations(errorMessage)
        transcription.handleError(errorMessage)
    }

    func handleSkills(_ store: ConnectionStore, _ newSkills: [Skill]) {
        skills = newSkills
        store.events.send(.skills(newSkills))
    }

    func handleDisconnect() {
        if hasRunningOutputs {
            AppLogger.connectionInfo("handleDisconnect envId=\(environmentId.uuidString)")
            conversationRuntime.handleConnectionLoss()
        }
        resetServerState()
        BackgroundStreamingTask.end()
    }
}

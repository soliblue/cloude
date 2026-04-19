import Combine
import Foundation
import CloudeShared

extension EnvironmentConnection {
    func handleAuthResult(_ mgr: EnvironmentStore, success: Bool, errorMessage: String?) {
        phase = success ? .authenticated : .connected
        if success {
            checkForMissedResponse()
            git.sendNextStatusIfReady()
            mgr.events.send(.authenticated(environmentId: environmentId))
        } else {
            lastError = errorMessage ?? "Authentication failed"
        }
    }

    func handleError(_ errorMessage: String) {
        lastError = errorMessage
        files.failPendingOperations(errorMessage)
        git.failPendingOperations(errorMessage)
        if errorMessage.lowercased().contains("transcription") && isTranscribing {
            isTranscribing = false
            AudioRecorder.markTranscriptionFailed()
        }
    }

    func handleTranscription(_ mgr: EnvironmentStore, _ text: String) {
        isTranscribing = false
        mgr.events.send(.transcription(text))
    }

    func handleSkills(_ mgr: EnvironmentStore, _ newSkills: [Skill]) {
        skills = newSkills
        mgr.events.send(.skills(newSkills))
    }

    func handleNameSuggestion(_ mgr: EnvironmentStore, name: String, symbol: String?, conversationId: String) {
        if let id = UUID(uuidString: conversationId) {
            mgr.events.send(.renameConversation(conversationId: id, name: name))
            if let s = symbol {
                mgr.events.send(.setConversationSymbol(conversationId: id, symbol: s))
            }
        }
    }
}

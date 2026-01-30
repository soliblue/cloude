// ConnectionManager+API.swift

import Foundation

extension ConnectionManager {
    func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(ServerMessage.self, from: data) else {
            return
        }

        switch message {
        case .output(let text):
            if let convId = runningConversationId {
                output(for: convId).text += text
            }

        case .fileChange:
            break

        case .status(let state):
            agentState = state
            if let convId = runningConversationId {
                let out = output(for: convId)
                out.isRunning = (state == .running)
                if state == .idle {
                    runningConversationId = nil
                }
            }

        case .authRequired:
            authenticate()

        case .authResult(let success, let errorMessage):
            isAuthenticated = success
            if success {
                checkForMissedResponse()
            } else {
                lastError = errorMessage ?? "Authentication failed"
            }

        case .error(let errorMessage):
            lastError = errorMessage

        case .image:
            break

        case .directoryListing(let path, let entries):
            onDirectoryListing?(path, entries)

        case .fileContent(let path, let data, let mimeType, let size):
            onFileContent?(path, data, mimeType, size)

        case .sessionId(let id):
            if let convId = runningConversationId {
                output(for: convId).newSessionId = id
            }

        case .missedResponse(let sessionId, let text, _):
            if let interrupted = interruptedSession, interrupted.sessionId == sessionId {
                output(for: interrupted.conversationId).text = text
                output(for: interrupted.conversationId).isRunning = false
                interruptedSession = nil
            }
            onMissedResponse?(sessionId, text, Date())

        case .noMissedResponse(let sessionId):
            if let interrupted = interruptedSession, interrupted.sessionId == sessionId {
                interruptedSession = nil
            }

        case .toolCall(let name, let input, let toolId, let parentToolId):
            if let convId = runningConversationId {
                output(for: convId).toolCalls.append(ToolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId))
            }

        case .runStats(let durationMs, let costUsd):
            if let convId = runningConversationId {
                output(for: convId).runStats = (durationMs, costUsd)
            }

        case .gitStatusResult(let status):
            onGitStatus?(status)

        case .gitDiffResult(let path, let diff):
            onGitDiff?(path, diff)

        case .gitCommitResult:
            break

        case .transcription(let text):
            print("[ConnectionManager] Received transcription: \(text)")
            onTranscription?(text)

        case .whisperReady(let ready):
            print("[ConnectionManager] Whisper ready: \(ready)")
            isWhisperReady = ready
        }
    }

    func sendChat(_ message: String, workingDirectory: String? = nil, sessionId: String? = nil, isNewSession: Bool = true, conversationId: UUID? = nil, imageBase64: String? = nil) {
        if !isAuthenticated {
            reconnectIfNeeded()
        }
        if let convId = conversationId {
            runningConversationId = convId
            output(for: convId).reset()
            output(for: convId).isRunning = true
        }
        send(.chat(message: message, workingDirectory: workingDirectory, sessionId: sessionId, isNewSession: isNewSession, imageBase64: imageBase64))
    }

    func abort() {
        send(.abort)
    }

    func listDirectory(path: String) {
        if !isAuthenticated { reconnectIfNeeded() }
        send(.listDirectory(path: path))
    }

    func getFile(path: String) {
        if !isAuthenticated { reconnectIfNeeded() }
        send(.getFile(path: path))
    }

    func requestMissedResponse(sessionId: String) {
        if !isAuthenticated { reconnectIfNeeded() }
        send(.requestMissedResponse(sessionId: sessionId))
    }

    func gitStatus(path: String) {
        if !isAuthenticated { reconnectIfNeeded() }
        send(.gitStatus(path: path))
    }

    func gitDiff(path: String, file: String? = nil) {
        if !isAuthenticated { reconnectIfNeeded() }
        send(.gitDiff(path: path, file: file))
    }

    func gitCommit(path: String, message: String, files: [String]) {
        if !isAuthenticated { reconnectIfNeeded() }
        send(.gitCommit(path: path, message: message, files: files))
    }

    func transcribe(audioBase64: String) {
        if !isAuthenticated { reconnectIfNeeded() }
        send(.transcribe(audioBase64: audioBase64))
    }
}

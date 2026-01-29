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
            onOutput?(text)

        case .fileChange(let path, let diff, let content):
            onFileChange?(path, diff, content)

        case .status(let state):
            agentState = state

        case .authRequired:
            authenticate()

        case .authResult(let success, let errorMessage):
            isAuthenticated = success
            if !success {
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
            onSessionId?(id)

        case .missedResponse(let sessionId, let text, let completedAt):
            onMissedResponse?(sessionId, text, completedAt)

        case .noMissedResponse:
            break

        case .toolCall(let name, let input, let toolId, let parentToolId):
            onToolCall?(name, input, toolId, parentToolId)

        case .runStats(let durationMs, let costUsd):
            onRunStats?(durationMs, costUsd)

        case .gitStatusResult(let status):
            onGitStatus?(status)

        case .gitDiffResult(let path, let diff):
            onGitDiff?(path, diff)

        case .gitCommitResult(let success, let message):
            onGitCommit?(success, message)
        }
    }

    func sendChat(_ message: String, workingDirectory: String? = nil, sessionId: String? = nil, isNewSession: Bool = true) {
        if !isAuthenticated {
            reconnectIfNeeded()
        }
        send(.chat(message: message, workingDirectory: workingDirectory, sessionId: sessionId, isNewSession: isNewSession))
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
}

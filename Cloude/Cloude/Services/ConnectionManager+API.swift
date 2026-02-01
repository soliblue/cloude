import Foundation
import Combine
import CloudeShared

private func extractToolDetail(name: String, input: String) -> String? {
    switch name {
    case "Bash":
        if let data = input.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let command = json["command"] as? String {
            let firstLine = command.components(separatedBy: .newlines).first ?? command
            let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
            if trimmed.count > 40 {
                return String(trimmed.prefix(37)) + "..."
            }
            return trimmed
        }
    case "Read", "Write", "Edit":
        if let data = input.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let path = json["file_path"] as? String {
            return (path as NSString).lastPathComponent
        }
    case "Grep":
        if let data = input.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let pattern = json["pattern"] as? String {
            if pattern.count > 30 {
                return String(pattern.prefix(27)) + "..."
            }
            return pattern
        }
    case "Glob":
        if let data = input.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let pattern = json["pattern"] as? String {
            return pattern
        }
    case "Task":
        if let data = input.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let desc = json["description"] as? String {
            return desc
        }
    default:
        break
    }
    return nil
}

extension ConnectionManager {
    func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(ServerMessage.self, from: data) else {
            return
        }

        switch message {
        case .output(let text, let conversationId):
            if let convIdStr = conversationId, let convId = UUID(uuidString: convIdStr) {
                output(for: convId).text += text
            } else if let convId = runningConversationId {
                output(for: convId).text += text
            }

        case .fileChange:
            break

        case .status(let state, let conversationId):
            agentState = state
            let targetConvId: UUID? = conversationId.flatMap { UUID(uuidString: $0) } ?? runningConversationId
            if let convId = targetConvId {
                let out = output(for: convId)
                out.isRunning = (state == .running || state == .compacting)
                out.isCompacting = (state == .compacting)
                if state == .idle {
                    LiveActivityManager.shared.endActivity(conversationId: convId)
                    runningConversationId = nil
                } else {
                    LiveActivityManager.shared.updateActivity(conversationId: convId, agentState: state)
                }
            }

        case .authRequired:
            authenticate()

        case .authResult(let success, let errorMessage):
            isAuthenticated = success
            if success {
                checkForMissedResponse()
                send(.getHeartbeatConfig)
            } else {
                lastError = errorMessage ?? "Authentication failed"
            }

        case .error(let errorMessage):
            lastError = errorMessage

        case .image:
            break

        case .directoryListing(let path, let entries):
            events.send(.directoryListing(path: path, entries: entries))
            onDirectoryListing?(path, entries)

        case .fileContent(let path, let data, let mimeType, let size):
            events.send(.fileContent(path: path, data: data, mimeType: mimeType, size: size))
            onFileContent?(path, data, mimeType, size)

        case .sessionId(let id, let conversationId):
            let targetConvId: UUID? = conversationId.flatMap { UUID(uuidString: $0) } ?? runningConversationId
            if let convId = targetConvId {
                output(for: convId).newSessionId = id
                onSessionIdReceived?(convId, id)
            }

        case .missedResponse(let sessionId, let text, _):
            var interruptedConvId: UUID?
            var interruptedMsgId: UUID?
            if let interrupted = interruptedSession, interrupted.sessionId == sessionId {
                interruptedConvId = interrupted.conversationId
                interruptedMsgId = interrupted.messageId
                output(for: interrupted.conversationId).text = text
                output(for: interrupted.conversationId).isRunning = false
                interruptedSession = nil
            }
            events.send(.missedResponse(sessionId: sessionId, text: text, completedAt: Date()))
            onMissedResponse?(sessionId, text, Date(), interruptedConvId, interruptedMsgId)

        case .noMissedResponse(let sessionId):
            if let interrupted = interruptedSession, interrupted.sessionId == sessionId {
                interruptedSession = nil
            }

        case .toolCall(let name, let input, let toolId, let parentToolId, let conversationId, let textPosition):
            let targetConvId: UUID? = conversationId.flatMap { UUID(uuidString: $0) } ?? runningConversationId
            if let convId = targetConvId {
                let currentTextLength = output(for: convId).text.count
                let position = textPosition ?? currentTextLength
                output(for: convId).toolCalls.append(ToolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, textPosition: position))
                let detail = input.flatMap { extractToolDetail(name: name, input: $0) }
                LiveActivityManager.shared.updateActivity(conversationId: convId, agentState: .running, currentTool: name, toolDetail: detail)
            }

        case .runStats(let durationMs, let costUsd, let conversationId):
            let targetConvId: UUID? = conversationId.flatMap { UUID(uuidString: $0) } ?? runningConversationId
            if let convId = targetConvId {
                output(for: convId).runStats = (durationMs, costUsd)
            }

        case .gitStatusResult(let status):
            events.send(.gitStatus(status))
            onGitStatus?(status)

        case .gitDiffResult(let path, let diff):
            events.send(.gitDiff(path: path, diff: diff))
            onGitDiff?(path, diff)

        case .gitCommitResult:
            break

        case .transcription(let text):
            events.send(.transcription(text))
            onTranscription?(text)

        case .whisperReady(let ready):
            print("[ConnectionManager] Whisper ready: \(ready)")
            isWhisperReady = ready

        case .heartbeatConfig(let intervalMinutes, let unreadCount):
            print("[Heartbeat] Received config: interval=\(String(describing: intervalMinutes)), unread=\(unreadCount)")
            events.send(.heartbeatConfig(intervalMinutes: intervalMinutes, unreadCount: unreadCount))
            onHeartbeatConfig?(intervalMinutes, unreadCount)

        case .memories(let sections):
            events.send(.memories(sections))
            onMemories?(sections)

        case .renameConversation(let conversationId, let name):
            if let convId = UUID(uuidString: conversationId) {
                onRenameConversation?(convId, name)
            }

        case .setConversationSymbol(let conversationId, let symbol):
            if let convId = UUID(uuidString: conversationId) {
                onSetConversationSymbol?(convId, symbol)
            }

        case .processList(let procs):
            processes = procs
            onProcessList?(procs)

        case .memoryAdded(let target, let section, let text, let conversationId):
            let targetConvId: UUID? = conversationId.flatMap { UUID(uuidString: $0) } ?? runningConversationId
            if let convId = targetConvId {
                let memoryCall = ToolCall(
                    name: "Memory",
                    input: "\(target): \(section) - \(text)",
                    toolId: UUID().uuidString,
                    parentToolId: nil,
                    textPosition: output(for: convId).text.count
                )
                output(for: convId).toolCalls.append(memoryCall)
            }
            onMemoryAdded?(target, section, text)

        case .defaultWorkingDirectory(let path):
            defaultWorkingDirectory = path

        case .skills(let newSkills):
            skills = newSkills
            events.send(.skills(newSkills))
            onSkills?(newSkills)

        case .historySync(let sessionId, let messages):
            events.send(.historySync(sessionId: sessionId, messages: messages))
            onHistorySync?(sessionId, messages)

        case .historySyncError(let sessionId, let error):
            events.send(.historySyncError(sessionId: sessionId, error: error))
            onHistorySyncError?(sessionId, error)
        }
    }

    func sendChat(_ message: String, workingDirectory: String? = nil, sessionId: String? = nil, isNewSession: Bool = true, conversationId: UUID? = nil, imageBase64: String? = nil, conversationName: String? = nil, conversationSymbol: String? = nil) {
        if !isAuthenticated {
            reconnectIfNeeded()
        }
        if let convId = conversationId {
            runningConversationId = convId
            output(for: convId).reset()
            output(for: convId).isRunning = true
            LiveActivityManager.shared.startActivity(
                conversationId: convId,
                conversationName: conversationName ?? "Chat",
                conversationSymbol: conversationSymbol
            )
        }
        let effectiveWorkingDir = workingDirectory ?? defaultWorkingDirectory
        send(.chat(message: message, workingDirectory: effectiveWorkingDir, sessionId: sessionId, isNewSession: isNewSession, imageBase64: imageBase64, conversationId: conversationId?.uuidString))
    }

    func abort(conversationId: UUID? = nil) {
        send(.abort(conversationId: conversationId?.uuidString))
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

    func getProcesses() {
        if !isAuthenticated { reconnectIfNeeded() }
        send(.getProcesses)
    }

    func killProcess(pid: Int32) {
        if !isAuthenticated { reconnectIfNeeded() }
        send(.killProcess(pid: pid))
    }

    func killAllProcesses() {
        if !isAuthenticated { reconnectIfNeeded() }
        send(.killAllProcesses)
    }

    func syncHistory(sessionId: String, workingDirectory: String) {
        if !isAuthenticated { reconnectIfNeeded() }
        send(.syncHistory(sessionId: sessionId, workingDirectory: workingDirectory))
    }
}

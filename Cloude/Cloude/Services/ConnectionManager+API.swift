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
    private func targetConversationId(from conversationId: String?) -> UUID? {
        conversationId.flatMap { UUID(uuidString: $0) } ?? runningConversationId
    }

    func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(ServerMessage.self, from: data) else {
            return
        }

        switch message {
        case .output(let text, let conversationId):
            if let convIdStr = conversationId, let convId = UUID(uuidString: convIdStr) {
                let out = output(for: convId)
                out.text += text
                if !out.isRunning {
                    out.isRunning = true
                    runningConversationId = convId
                }
            } else if let convId = runningConversationId {
                output(for: convId).text += text
            }

        case .fileChange:
            break

        case .status(let state, let conversationId):
            if agentState != state { agentState = state }
            if let convId = targetConversationId(from: conversationId) {
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
            if errorMessage.lowercased().contains("transcription") && isTranscribing {
                isTranscribing = false
                AudioRecorder.markTranscriptionFailed()
            }

        case .image:
            break

        case .directoryListing(let path, let entries):
            events.send(.directoryListing(path: path, entries: entries))
            onDirectoryListing?(path, entries)

        case .fileContent(let path, let data, let mimeType, let size, let truncated):
            events.send(.fileContent(path: path, data: data, mimeType: mimeType, size: size, truncated: truncated))
            onFileContent?(path, data, mimeType, size, truncated)

        case .fileChunk(let path, let chunkIndex, let totalChunks, let data, let mimeType, let size):
            print("[ConnectionManager] Received chunk \(chunkIndex + 1)/\(totalChunks) for \(path), data size: \(data.count)")
            chunkProgress = ChunkProgress(path: path, current: chunkIndex, total: totalChunks)
            events.send(.fileChunk(path: path, chunkIndex: chunkIndex, totalChunks: totalChunks, data: data, mimeType: mimeType, size: size))
            if pendingChunks[path] == nil {
                pendingChunks[path] = (chunks: [:], totalChunks: totalChunks, mimeType: mimeType, size: size)
            }
            pendingChunks[path]?.chunks[chunkIndex] = data
            print("[ConnectionManager] Stored chunk \(chunkIndex), have \(pendingChunks[path]?.chunks.count ?? 0)/\(totalChunks)")
            if let pending = pendingChunks[path], (0..<pending.totalChunks).allSatisfy({ pending.chunks[$0] != nil }) {
                print("[ConnectionManager] All chunks received, combining...")
                var combinedData = Data()
                for i in 0..<pending.totalChunks {
                    if let chunkBase64 = pending.chunks[i], let chunkData = Data(base64Encoded: chunkBase64) {
                        combinedData.append(chunkData)
                        print("[ConnectionManager] Decoded chunk \(i): \(chunkData.count) bytes")
                    } else {
                        print("[ConnectionManager] FAILED to decode chunk \(i)")
                    }
                }
                let combinedBase64 = combinedData.base64EncodedString()
                print("[ConnectionManager] Combined: \(combinedData.count) bytes, base64: \(combinedBase64.count) chars")
                pendingChunks.removeValue(forKey: path)
                events.send(.fileContent(path: path, data: combinedBase64, mimeType: pending.mimeType, size: pending.size, truncated: false))
                onFileContent?(path, combinedBase64, pending.mimeType, pending.size, false)
            }

        case .fileThumbnail(let path, let data, let fullSize):
            events.send(.fileThumbnail(path: path, data: data, fullSize: fullSize))

        case .sessionId(let id, let conversationId):
            if let convId = targetConversationId(from: conversationId) {
                output(for: convId).newSessionId = id
                onSessionIdReceived?(convId, id)
            }

        case .missedResponse(let sessionId, let text, _, let storedToolCalls):
            var interruptedConvId: UUID?
            var interruptedMsgId: UUID?
            let toolCalls = storedToolCalls.map { ToolCall(name: $0.name, input: $0.input, toolId: $0.toolId, parentToolId: $0.parentToolId, textPosition: $0.textPosition) }
            if let interrupted = interruptedSession, interrupted.sessionId == sessionId {
                interruptedConvId = interrupted.conversationId
                interruptedMsgId = interrupted.messageId
                output(for: interrupted.conversationId).text = text
                output(for: interrupted.conversationId).toolCalls = toolCalls
                output(for: interrupted.conversationId).isRunning = false
                interruptedSession = nil
            }
            events.send(.missedResponse(sessionId: sessionId, text: text, completedAt: Date(), toolCalls: storedToolCalls))
            onMissedResponse?(sessionId, text, toolCalls, Date(), interruptedConvId, interruptedMsgId)

        case .noMissedResponse(let sessionId):
            if let interrupted = interruptedSession, interrupted.sessionId == sessionId {
                interruptedSession = nil
            }

        case .toolCall(let name, let input, let toolId, let parentToolId, let conversationId, let textPosition):
            if let convId = targetConversationId(from: conversationId) {
                let currentTextLength = output(for: convId).text.count
                let position = textPosition ?? currentTextLength
                output(for: convId).toolCalls.append(ToolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, textPosition: position))
                let detail = input.flatMap { extractToolDetail(name: name, input: $0) }
                LiveActivityManager.shared.updateActivity(conversationId: convId, agentState: .running, currentTool: name, toolDetail: detail)
            }

        case .runStats(let durationMs, let costUsd, let conversationId):
            if let convId = targetConversationId(from: conversationId) {
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
            isTranscribing = false
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
            if let convId = targetConversationId(from: conversationId) {
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

        case .heartbeatSkipped(let conversationId):
            if let convId = targetConversationId(from: conversationId) {
                output(for: convId).skipped = true
            }
            onHeartbeatSkipped?(conversationId)

        case .deleteConversation(let conversationId):
            if let convId = UUID(uuidString: conversationId) {
                onDeleteConversation?(convId)
            }

        case .notify(let title, let body, _):
            onNotify?(title, body)

        case .clipboard(let text):
            onClipboard?(text)

        case .openURL(let url):
            onOpenURL?(url)

        case .haptic(let style):
            onHaptic?(style)

        case .speak(let text):
            onSpeak?(text)

        case .switchConversation(let conversationId):
            if let convId = UUID(uuidString: conversationId) {
                onSwitchConversation?(convId)
            }

        case .question(let questions, let conversationId):
            let convId = conversationId.flatMap { UUID(uuidString: $0) }
            onQuestion?(questions, convId)

        case .fileSearchResults(let files, let query):
            onFileSearchResults?(files, query)
        }
    }

    func searchFiles(query: String, workingDirectory: String) {
        if !isAuthenticated { reconnectIfNeeded() }
        send(.searchFiles(query: query, workingDirectory: workingDirectory))
    }

    func sendChat(_ message: String, workingDirectory: String? = nil, sessionId: String? = nil, isNewSession: Bool = true, conversationId: UUID? = nil, imageBase64: String? = nil, conversationName: String? = nil, conversationSymbol: String? = nil, forkSession: Bool = false) {
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
        send(.chat(message: message, workingDirectory: effectiveWorkingDir, sessionId: sessionId, isNewSession: isNewSession, imageBase64: imageBase64, conversationId: conversationId?.uuidString, conversationName: conversationName, forkSession: forkSession))
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

    func getFileFullQuality(path: String) {
        print("[ConnectionManager] getFileFullQuality called for: \(path)")
        if !isAuthenticated { reconnectIfNeeded() }
        send(.getFileFullQuality(path: path))
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
        isTranscribing = true
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

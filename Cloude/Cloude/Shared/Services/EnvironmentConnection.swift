import Foundation
import Combine
import CloudeShared
import OSLog

@MainActor
class EnvironmentConnection: ObservableObject, Identifiable {
    let environmentId: UUID

    @Published var phase: ConnectionPhase = .disconnected
    @Published var isWhisperReady = false
    @Published var isTranscribing = false
    @Published var agentState: AgentState = .idle
    @Published var lastError: String?
    @Published var defaultWorkingDirectory: String?
    @Published var skills: [Skill] = []
    @Published var chunkProgress: ChunkProgress?
    @Published var latencyMs: Double?
    @Published var directoryListings: [String: [FileEntry]] = [:]
    @Published var fileResponses: [String: LoadedFileState] = [:]
    @Published var pathErrors: [String: String] = [:]
    @Published var gitStatuses: [String: GitStatusInfo] = [:]
    @Published var gitStatusErrors: [String: String] = [:]
    @Published var gitLogs: [String: [GitCommit]] = [:]
    @Published var gitLogErrors: [String: String] = [:]
    @Published var gitDiffs: [GitDiffCacheKey: String] = [:]
    @Published var gitDiffErrors: [GitDiffCacheKey: String] = [:]
    @Published var fileSearchResults: [String] = []
    @Published var fileSearchError: String?

    var symbol: String = "laptopcomputer"
    let gitStatus = GitStatusService()
    var fileCache = FileCache()
    var pendingChunks: [String: PendingChunk] = [:]
    var pendingPathRequests: Set<String> = []
    var pendingGitLogPaths: Set<String> = []
    var pendingGitDiffRequest: GitDiffCacheKey?
    var hasPendingFileSearch = false
    var interruptedSessions: [String: InterruptedSession] = [:]
    var conversationOutputs: [UUID: ConversationOutput] = [:]

    var webSocket: URLSessionWebSocketTask?
    var session: URLSession?
    var savedHost: String = ""
    var savedPort: UInt16 = 8765
    var savedToken: String = ""
    var connectionToken = UUID()

    weak var manager: EnvironmentStore?

    var id: UUID { environmentId }

    var hasCredentials: Bool {
        !savedHost.isEmpty && !savedToken.isEmpty
    }

    var isReady: Bool {
        phase == .authenticated
    }

    var isConnecting: Bool {
        phase == .connected
    }

    var runningOutputs: [(conversationId: UUID, output: ConversationOutput)] {
        conversationOutputs.compactMap { (convId, output) in
            output.phase != .idle ? (convId, output) : nil
        }
    }

    init(environmentId: UUID) {
        self.environmentId = environmentId
        gitStatus.send = { [weak self] path in
            if let self {
                AppLogger.connectionInfo("git status request envId=\(self.environmentId.uuidString) path=\(path)")
            }
            self?.send(.gitStatus(path: path))
        }
        gitStatus.canSend = { [weak self] in
            self?.isReady == true
        }
    }

    func directoryListing(for path: String) -> [FileEntry]? {
        directoryListings[path]
    }

    func fileResponse(for path: String) -> LoadedFileState? {
        fileResponses[path]
    }

    func pathError(for path: String) -> String? {
        pathErrors[path]
    }

    func gitStatusInfo(for path: String) -> GitStatusInfo? {
        gitStatuses[path]
    }

    func gitStatusError(for path: String) -> String? {
        gitStatusErrors[path]
    }

    func gitLogEntries(for path: String) -> [GitCommit]? {
        gitLogs[path]
    }

    func gitLogError(for path: String) -> String? {
        gitLogErrors[path]
    }

    func gitDiffText(repoPath: String, file: String? = nil, staged: Bool = false) -> String? {
        gitDiffs[GitDiffCacheKey(repoPath: repoPath, filePath: file, staged: staged)]
    }

    func gitDiffError(repoPath: String, file: String? = nil, staged: Bool = false) -> String? {
        gitDiffErrors[GitDiffCacheKey(repoPath: repoPath, filePath: file, staged: staged)]
    }

    func clearFileSearchResults() {
        fileSearchResults = []
        fileSearchError = nil
        hasPendingFileSearch = false
    }

    func connect(host: String, port: UInt16, token: String) {
        AppLogger.connectionInfo("connect envId=\(environmentId.uuidString) host=\(host):\(port)")
        savedHost = host
        savedPort = port
        savedToken = token
        reconnect()
    }

    func reconnect() {
        if hasCredentials {
            disconnect(clearCredentials: false)
            connectionToken = UUID()

            let isIP = savedHost.allSatisfy { $0.isNumber || $0 == "." || $0 == ":" }
            let scheme = isIP ? "ws" : "wss"
            if let url = URL(string: "\(scheme)://\(savedHost):\(savedPort)") {
                AppLogger.connectionInfo("reconnect envId=\(environmentId.uuidString) url=\(url.absoluteString)")
                AppLogger.beginInterval("environment.auth", key: environmentId.uuidString, details: "url=\(url.absoluteString)")

                session = URLSession(configuration: .default)
                webSocket = session?.webSocketTask(with: url)
                webSocket?.resume()

                phase = .connected
                lastError = nil

                receiveMessage(token: connectionToken)
            } else {
                lastError = "Invalid URL"
                AppLogger.connectionError("invalid URL envId=\(environmentId.uuidString) host=\(savedHost) port=\(savedPort)")
            }
        }
    }

    func reconnectIfNeeded() {
        if hasCredentials, phase == .disconnected {
            reconnect()
        }
    }

    func disconnect(clearCredentials: Bool = true) {
        AppLogger.connectionInfo("disconnect envId=\(environmentId.uuidString) clearCredentials=\(clearCredentials)")
        connectionToken = UUID()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        session = nil
        if !runningOutputs.isEmpty {
            handleDisconnect()
        } else {
            resetServerState()
        }

        if clearCredentials {
            savedHost = ""
            savedToken = ""
        }

    }

    func authenticate() {
        AppLogger.connectionInfo("authenticate envId=\(environmentId.uuidString)")
        send(.auth(token: savedToken))
    }

    func checkForMissedResponse() {
        for (sessionId, target) in interruptedSessions {
            let lastSeenSeq = output(for: target.conversationId).lastSeenSeq
            AppLogger.connectionInfo("heuristic_counter=resumeFrom_send sessionId=\(sessionId) lastSeq=\(lastSeenSeq)")
            send(.resumeFrom(sessionId: sessionId, lastSeq: lastSeenSeq))
        }
    }

    func receiveMessage(token: UUID) {
        webSocket?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                if let self, token == self.connectionToken {
                    switch result {
                    case .success(let message):
                        switch message {
                        case .string(let text):
                            self.handleMessage(text)
                        case .data(let data):
                            if let text = String(data: data, encoding: .utf8) {
                                self.handleMessage(text)
                            }
                        @unknown default:
                            break
                        }
                        self.receiveMessage(token: token)

                    case .failure(let error):
                        self.lastError = error.localizedDescription
                        AppLogger.connectionError("receive failed envId=\(self.environmentId.uuidString) error=\(error.localizedDescription)")
                        self.handleDisconnect()
                    }
                }
            }
        }
    }

    func send(_ message: ClientMessage) {
        if let data = try? JSONEncoder().encode(message),
           let text = String(data: data, encoding: .utf8) {
            webSocket?.send(.string(text)) { [weak self] error in
                if let error = error {
                    Task { @MainActor [weak self] in
                        self?.lastError = error.localizedDescription
                        if let self {
                            AppLogger.connectionError("send failed envId=\(self.environmentId.uuidString) error=\(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    func sendChat(_ message: String, workingDirectory: String? = nil, sessionId: String? = nil, isNewSession: Bool = true, conversationId: UUID? = nil, imagesBase64: [String]? = nil, filesBase64: [AttachedFilePayload]? = nil, conversationName: String? = nil, forkSession: Bool = false, effort: String? = nil, model: String? = nil) {
        if let convId = conversationId {
            AppLogger.beginInterval("chat.firstToken", key: convId.uuidString, details: "chars=\(message.count)")
            AppLogger.beginInterval("chat.complete", key: convId.uuidString, details: "chars=\(message.count)")
            output(for: convId).reset()
            output(for: convId).phase = .running
        }
        send(.chat(message: message, workingDirectory: workingDirectory ?? defaultWorkingDirectory, sessionId: sessionId, isNewSession: isNewSession, imagesBase64: imagesBase64, filesBase64: filesBase64, conversationId: conversationId?.uuidString, conversationName: conversationName, forkSession: forkSession, effort: effort, model: model))
    }

    func abort(conversationId: UUID? = nil) {
        send(.abort(conversationId: conversationId?.uuidString))
    }

    func searchFiles(query: String, workingDirectory: String) {
        fileSearchResults = []
        fileSearchError = nil
        hasPendingFileSearch = true
        AppLogger.connectionInfo("file search request envId=\(environmentId.uuidString) workingDirectory=\(workingDirectory) query=\(query)")
        send(.searchFiles(query: query, workingDirectory: workingDirectory))
    }

    func listDirectory(path: String) {
        pendingPathRequests.insert(path)
        pathErrors.removeValue(forKey: path)
        AppLogger.connectionInfo("directory request envId=\(environmentId.uuidString) path=\(path)")
        send(.listDirectory(path: path))
    }

    func getFile(path: String) {
        pendingPathRequests.insert(path)
        pathErrors.removeValue(forKey: path)
        chunkProgress = nil
        AppLogger.connectionInfo("file request envId=\(environmentId.uuidString) path=\(path) quality=default")
        send(.getFile(path: path))
    }

    func getFileFullQuality(path: String) {
        pendingPathRequests.insert(path)
        pathErrors.removeValue(forKey: path)
        chunkProgress = nil
        AppLogger.connectionInfo("file request envId=\(environmentId.uuidString) path=\(path) quality=full")
        send(.getFileFullQuality(path: path))
    }

    func gitLog(path: String, count: Int = 10) {
        pendingGitLogPaths.insert(path)
        gitLogErrors.removeValue(forKey: path)
        AppLogger.connectionInfo("git log request envId=\(environmentId.uuidString) path=\(path) count=\(count)")
        send(.gitLog(path: path, count: count))
    }

    func gitDiff(path: String, file: String? = nil, staged: Bool = false) {
        let key = GitDiffCacheKey(repoPath: path, filePath: file, staged: staged)
        pendingGitDiffRequest = key
        gitDiffErrors.removeValue(forKey: key)
        AppLogger.connectionInfo("git diff request envId=\(environmentId.uuidString) repoPath=\(path) file=\(file ?? "-") staged=\(staged)")
        send(.gitDiff(path: path, file: file, staged: staged))
    }

    func syncHistory(sessionId: String, workingDirectory: String) { send(.syncHistory(sessionId: sessionId, workingDirectory: workingDirectory)) }

    func transcribe(audioBase64: String) {
        isTranscribing = true
        send(.transcribe(audioBase64: audioBase64))
    }

    func requestNameSuggestion(text: String, context: [String], conversationId: UUID) {
        send(.suggestName(text: text, context: context, conversationId: conversationId.uuidString))
    }

    func handleMessage(_ text: String) {
        if let data = text.data(using: .utf8),
           let message = try? JSONDecoder().decode(ServerMessage.self, from: data),
           let mgr = manager {
            switch message {
            case .output(let text, let conversationId, let seq): handleOutput(mgr, text: text, conversationId: conversationId, seq: seq)
            case .status(let state, let conversationId):      handleStatus(mgr, state: state, conversationId: conversationId)
            case .authRequired:
                AppLogger.connectionInfo("auth required envId=\(environmentId.uuidString)")
                authenticate()
            case .authResult(let success, let msg):
                AppLogger.connectionInfo("auth result envId=\(environmentId.uuidString) success=\(success) message=\(msg ?? "")")
                AppLogger.endInterval("environment.auth", key: environmentId.uuidString, details: "success=\(success)")
                handleAuthResult(mgr, success: success, errorMessage: msg)
            case .error(let msg):
                AppLogger.connectionError("server error envId=\(environmentId.uuidString) message=\(msg)")
                if let path = gitStatus.completeInFlight() {
                    gitStatusErrors[path] = msg
                }
                handleError(mgr, msg)
            case .toolCall(let n, let i, let t, let p, let c, let pos, let ei, let seq): handleToolCall(mgr, name: n, input: i, toolId: t, parentToolId: p, conversationId: c, textPosition: pos, editInfo: ei, seq: seq)
            case .toolResult(let id, _, let out, let c, let seq):  handleToolResult(mgr, toolId: id, output: out, conversationId: c, seq: seq)
            case .runStats(let ms, let cost, let m, let c, let seq):    handleRunStats(mgr, durationMs: ms, costUsd: cost, model: m, conversationId: c, seq: seq)
            case .resumeFromResponse(let sid, let events, let historyOnly): handleResumeFromResponse(mgr, sessionId: sid, events: events, historyOnly: historyOnly)
            case .sessionId(let id, let c):                   handleSessionId(mgr, id, conversationId: c)
            case .messageUUID(let uuid, let c):               handleMessageUUID(mgr, uuid, conversationId: c)
            case .directoryListing(let path, let entries):    handleDirectoryListing(path: path, entries: entries)
            case .fileContent(let p, let d, let m, let s, let t): handleFileContent(path: p, data: d, mimeType: m, size: s, truncated: t)
            case .fileChunk(let p, let ci, let tc, let d, let m, let s): handleFileChunk(path: p, chunkIndex: ci, totalChunks: tc, data: d, mimeType: m, size: s)
            case .fileThumbnail(let p, let d, let fs):        handleFileThumbnail(path: p, data: d, fullSize: fs)
            case .fileSearchResults(let files):               handleFileSearchResults(files)
            case .gitStatusResult(let status):                handleGitStatusResult(status)
            case .gitDiffResult(let path, let diff):          handleGitDiffResult(path: path, diff: diff)
            case .gitLogResult(let path, let commits):        handleGitLogResult(path: path, commits: commits)
            case .transcription(let text):                    handleTranscription(mgr, text)
            case .whisperReady(let ready):                    isWhisperReady = ready
            case .skills(let s):                              handleSkills(mgr, s)
            case .defaultWorkingDirectory(let path):
                defaultWorkingDirectory = path
                mgr.events.send(.defaultWorkingDirectory(path: path, environmentId: environmentId))
            case .historySync(let sid, let msgs):             mgr.events.send(.historySync(sessionId: sid, messages: msgs))
            case .historySyncError(let sid, let err):          mgr.events.send(.historySyncError(sessionId: sid, error: err))
            case .nameSuggestion(let name, let sym, let c):   handleNameSuggestion(mgr, name: name, symbol: sym, conversationId: c)
            case .pong(let sentAt, _):                        latencyMs = (Date().timeIntervalSince1970 - sentAt) * 1000
            case .gitCommitResult:                            break
            }
        }
    }

    func handleResumeFromResponse(_ mgr: EnvironmentStore, sessionId: String, events: [ReplayedEvent], historyOnly: Bool) {
        AppLogger.connectionInfo("heuristic_counter=resumeFromResponse_receive sessionId=\(sessionId) events=\(events.count) historyOnly=\(historyOnly)")
        if historyOnly {
            if let target = interruptedSessions[sessionId] {
                let out = output(for: target.conversationId)
                out.requiresHistoryResync = true
            }
            return
        }
        if let target = interruptedSessions[sessionId], let messageId = target.messageId {
            mgr.events.send(.resumeBegin(conversationId: target.conversationId, messageId: messageId))
        }
        for event in events {
            switch event {
            case .output(let text, let conversationId, let seq):
                handleOutput(mgr, text: text, conversationId: conversationId, seq: seq)
            case .toolCall(let name, let input, let toolId, let parentToolId, let conversationId, let textPosition, let editInfo, let seq):
                handleToolCall(mgr, name: name, input: input, toolId: toolId, parentToolId: parentToolId, conversationId: conversationId, textPosition: textPosition, editInfo: editInfo, seq: seq)
            case .toolResult(let toolId, _, let output, let conversationId, let seq):
                handleToolResult(mgr, toolId: toolId, output: output, conversationId: conversationId, seq: seq)
            case .runStats(let durationMs, let costUsd, let model, let conversationId, let seq):
                handleRunStats(mgr, durationMs: durationMs, costUsd: costUsd, model: model, conversationId: conversationId, seq: seq)
            }
        }
    }

    func handleDisconnect() {
        if let mgr = manager {
            AppLogger.connectionInfo("handleDisconnect envId=\(environmentId.uuidString)")
            for (convId, output) in runningOutputs {
                output.flushBuffer()
                output.completeExecutingTools()
                let snapshot = ConversationOutput()
                snapshot.text = output.text
                snapshot.fullText = output.fullText
                snapshot.toolCalls = output.toolCalls
                snapshot.newSessionId = output.newSessionId
                snapshot.liveMessageId = output.liveMessageId
                mgr.events.send(.disconnect(conversationId: convId, output: snapshot))
                output.phase = .idle
            }
            resetServerState()
            BackgroundStreamingTask.end()
        }
    }

    func handleOutput(_ mgr: EnvironmentStore, text: String, conversationId: String?, seq: Int? = nil) {
        if let convId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            if let seq, seq <= output(for: convId).lastSeenSeq { return }
            AppLogger.connectionInfo("assistant output convId=\(convId.uuidString) chars=\(text.count) seq=\(seq.map(String.init) ?? "nil")")
            AppLogger.endInterval("chat.firstToken", key: convId.uuidString)
            let out = output(for: convId)
            out.completeExecutingTools(topLevelOnly: true)
            out.appendText(text)
            ensureRunning(out)
            if let seq { out.lastSeenSeq = max(out.lastSeenSeq, seq) }
        }
    }

    func handleToolCall(_ mgr: EnvironmentStore, name: String, input: String?, toolId: String, parentToolId: String?, conversationId: String?, textPosition: Int?, editInfo: EditInfo? = nil, seq: Int? = nil) {
        if let convId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            AppLogger.connectionInfo("tool call convId=\(convId.uuidString) toolId=\(toolId) name=\(name) seq=\(seq.map(String.init) ?? "nil")")
            let out = output(for: convId)
            ensureRunning(out)
            if parentToolId == nil {
                out.completeExecutingTools(topLevelOnly: true)
            }
            let currentTextLength = out.fullText.count
            let position = min(textPosition ?? currentTextLength, currentTextLength)
            out.toolCalls.append(ToolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, textPosition: position, state: .executing, editInfo: editInfo))
            mgr.events.send(.liveSnapshot(conversationId: convId))
            if let seq { out.lastSeenSeq = max(out.lastSeenSeq, seq) }
        }
    }

    func handleToolResult(_ mgr: EnvironmentStore, toolId: String, output: String?, conversationId: String?, seq: Int? = nil) {
        if let convId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            AppLogger.connectionInfo("tool result convId=\(convId.uuidString) toolId=\(toolId) outputChars=\(output?.count ?? 0) seq=\(seq.map(String.init) ?? "nil")")
            let out = self.output(for: convId)
            if !out.toolCalls.contains(where: { $0.toolId == toolId }) {
                AppLogger.connectionInfo("heuristic_counter=requiresHistoryResync_flip reason=tool_result_without_call convId=\(convId.uuidString) toolId=\(toolId)")
                out.requiresHistoryResync = true
            }
            out.toolCalls = out.toolCalls.map { tool in
                if tool.toolId == toolId {
                    var updated = tool
                    updated.state = .complete
                    updated.resultOutput = output
                    return updated
                }
                return tool
            }
            if let seq { out.lastSeenSeq = max(out.lastSeenSeq, seq) }
        }
    }

    func handleRunStats(_ mgr: EnvironmentStore, durationMs: Int, costUsd: Double, model: String?, conversationId: String?, seq: Int? = nil) {
        if let convId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            AppLogger.connectionInfo("run stats convId=\(convId.uuidString) durationMs=\(durationMs) costUsd=\(costUsd) seq=\(seq.map(String.init) ?? "nil")")
            AppLogger.endInterval("chat.complete", key: convId.uuidString, details: "serverDurationMs=\(durationMs) costUsd=\(costUsd)")
            let out = output(for: convId)
            out.runStats = RunStats(durationMs: durationMs, costUsd: costUsd, model: model)
            if let seq { out.lastSeenSeq = max(out.lastSeenSeq, seq) }
        }
    }

    func handleSessionId(_ mgr: EnvironmentStore, _ id: String, conversationId: String?) {
        if let convId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            AppLogger.connectionInfo("session id convId=\(convId.uuidString) sessionId=\(id)")
            output(for: convId).newSessionId = id
            mgr.events.send(.sessionIdReceived(conversationId: convId, sessionId: id))
        }
    }

    func handleMessageUUID(_ mgr: EnvironmentStore, _ uuid: String, conversationId: String?) {
        if let convId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            AppLogger.connectionInfo("message uuid convId=\(convId.uuidString) uuid=\(uuid)")
            output(for: convId).messageUUID = uuid
        }
    }

    func handleAuthResult(_ mgr: EnvironmentStore, success: Bool, errorMessage: String?) {
        phase = success ? .authenticated : .connected
        if success {
            checkForMissedResponse()
            gitStatus.sendNextIfReady()
            mgr.events.send(.authenticated(environmentId: environmentId))
        } else {
            lastError = errorMessage ?? "Authentication failed"
        }
    }

    func handleError(_ mgr: EnvironmentStore, _ errorMessage: String) {
        lastError = errorMessage
        failPendingOperations(errorMessage)
        if errorMessage.lowercased().contains("transcription") && isTranscribing {
            isTranscribing = false
            AudioRecorder.markTranscriptionFailed()
        }
    }

    func handleStatus(_ mgr: EnvironmentStore, state: AgentState, conversationId: String?) {
        if agentState != state { agentState = state }
        if let convId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            AppLogger.connectionInfo("status convId=\(convId.uuidString) state=\(state.rawValue)")
            let out = output(for: convId)
            if state == .idle {
                out.flushBuffer()
                out.completeExecutingTools()
                AppLogger.cancelInterval("chat.firstToken", key: convId.uuidString, reason: "idle")
                AppLogger.cancelInterval("chat.complete", key: convId.uuidString, reason: "idle")
                if let stats = out.runStats, stats.costUsd > 0 {
                    mgr.events.send(.lastAssistantMessageCostUpdate(conversationId: convId, costUsd: stats.costUsd))
                }
            }
            let oldPhase = out.phase
            out.phase = (state == .running) ? .running : (state == .compacting ? .compacting : .idle)
            if oldPhase == .idle && out.phase != .idle {
                mgr.events.send(.reconnectRunning(conversationId: convId))
            }
            if state == .idle {
                if oldPhase != .idle { mgr.events.send(.turnCompleted(conversationId: convId)) }
                let anyRunning = conversationOutputs.values.contains { $0.phase != .idle }
                if !anyRunning { BackgroundStreamingTask.end() }
            }
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

    func handleDirectoryListing(path: String, entries: [FileEntry]) {
        pendingPathRequests.remove(path)
        pathErrors.removeValue(forKey: path)
        fileResponses.removeValue(forKey: path)
        directoryListings[path] = entries
        AppLogger.connectionInfo("directory response envId=\(environmentId.uuidString) path=\(path) entries=\(entries.count)")
    }

    func handleFileContent(path: String, data: String, mimeType: String, size: Int64, truncated: Bool) {
        if let decoded = Data(base64Encoded: data) {
            fileCache.set(path, data: decoded)
        }
        pendingPathRequests.remove(path)
        pendingChunks.removeValue(forKey: path)
        pathErrors.removeValue(forKey: path)
        chunkProgress = nil
        directoryListings.removeValue(forKey: path)
        fileResponses[path] = .content(mimeType: mimeType, size: size, truncated: truncated)
        AppLogger.connectionInfo("file response envId=\(environmentId.uuidString) path=\(path) kind=content bytes=\(size) truncated=\(truncated) mimeType=\(mimeType)")
    }

    func handleFileChunk(path: String, chunkIndex: Int, totalChunks: Int, data: String, mimeType: String, size: Int64) {
        chunkProgress = ChunkProgress(path: path, current: chunkIndex, total: totalChunks)
        if pendingChunks[path] == nil {
            pendingChunks[path] = PendingChunk(chunks: [:], totalChunks: totalChunks, mimeType: mimeType, size: size)
        }
        pendingChunks[path]?.chunks[chunkIndex] = data
        if let pending = pendingChunks[path], (0..<pending.totalChunks).allSatisfy({ pending.chunks[$0] != nil }) {
            var combinedData = Data()
            for i in 0..<pending.totalChunks {
                if let chunkBase64 = pending.chunks[i], let chunkData = Data(base64Encoded: chunkBase64) {
                    combinedData.append(chunkData)
                }
            }
            handleFileContent(path: path, data: combinedData.base64EncodedString(), mimeType: pending.mimeType, size: pending.size, truncated: false)
        }
    }

    func handleFileThumbnail(path: String, data: String, fullSize: Int64) {
        if let decoded = Data(base64Encoded: data) {
            fileCache.set(path, data: decoded)
        }
        pendingPathRequests.remove(path)
        pathErrors.removeValue(forKey: path)
        chunkProgress = nil
        directoryListings.removeValue(forKey: path)
        fileResponses[path] = .thumbnail(fullSize: fullSize)
        AppLogger.connectionInfo("file response envId=\(environmentId.uuidString) path=\(path) kind=thumbnail bytes=\(fullSize)")
    }

    func handleFileSearchResults(_ files: [String]) {
        hasPendingFileSearch = false
        fileSearchError = nil
        fileSearchResults = files
        AppLogger.connectionInfo("file search response envId=\(environmentId.uuidString) count=\(files.count)")
    }

    func handleGitStatusResult(_ status: GitStatusInfo) {
        if let path = gitStatus.completeInFlight() {
            gitStatusErrors.removeValue(forKey: path)
            gitStatuses[path] = status
            AppLogger.connectionInfo("git status response envId=\(environmentId.uuidString) path=\(path) branch=\(status.branch) files=\(status.files.count)")
        }
    }

    func handleGitLogResult(path: String, commits: [GitCommit]) {
        pendingGitLogPaths.remove(path)
        gitLogErrors.removeValue(forKey: path)
        gitLogs[path] = commits
        AppLogger.connectionInfo("git log response envId=\(environmentId.uuidString) path=\(path) commits=\(commits.count)")
    }

    func handleGitDiffResult(path: String, diff: String) {
        if let key = pendingGitDiffRequest, key.repoPath == path {
            gitDiffErrors.removeValue(forKey: key)
            gitDiffs[key] = diff
            pendingGitDiffRequest = nil
            AppLogger.connectionInfo("git diff response envId=\(environmentId.uuidString) repoPath=\(path) file=\(key.filePath ?? "-") staged=\(key.staged) chars=\(diff.count)")
        }
    }

    func handleNameSuggestion(_ mgr: EnvironmentStore, name: String, symbol: String?, conversationId: String) {
        if let id = UUID(uuidString: conversationId) {
            mgr.events.send(.renameConversation(conversationId: id, name: name))
            if let s = symbol {
                mgr.events.send(.setConversationSymbol(conversationId: id, symbol: s))
            }
        }
    }

    func output(for conversationId: UUID) -> ConversationOutput {
        if let existing = conversationOutputs[conversationId] {
            return existing
        }
        let new = ConversationOutput()
        conversationOutputs[conversationId] = new
        return new
    }

    func resetServerState() {
        phase = .disconnected
        isWhisperReady = false
        isTranscribing = false
        agentState = .idle
        chunkProgress = nil
        directoryListings = [:]
        fileResponses = [:]
        pathErrors = [:]
        gitStatuses = [:]
        gitStatusErrors = [:]
        gitLogs = [:]
        gitLogErrors = [:]
        gitDiffs = [:]
        gitDiffErrors = [:]
        fileSearchResults = []
        fileSearchError = nil
        pendingPathRequests = []
        pendingChunks = [:]
        pendingGitLogPaths = []
        pendingGitDiffRequest = nil
        hasPendingFileSearch = false
        gitStatus.reset()
    }

    func failPendingOperations(_ message: String) {
        for path in pendingPathRequests {
            pathErrors[path] = message
        }
        for path in pendingGitLogPaths {
            gitLogErrors[path] = message
        }
        if let pendingGitDiffRequest {
            gitDiffErrors[pendingGitDiffRequest] = message
        }
        if hasPendingFileSearch {
            fileSearchError = message
            fileSearchResults = []
        }
        pendingPathRequests = []
        pendingChunks = [:]
        pendingGitLogPaths = []
        pendingGitDiffRequest = nil
        hasPendingFileSearch = false
        chunkProgress = nil
    }

    private func ensureRunning(_ out: ConversationOutput) {
        if out.phase == .idle { out.phase = .running }
    }
}

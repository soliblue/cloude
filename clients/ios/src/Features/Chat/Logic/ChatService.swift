import Foundation
import SwiftData
import UIKit

enum ChatService {
    @MainActor private static var streamingMessages: [UUID: ChatMessage] = [:]
    @MainActor private static var pendingUserMessages: [UUID: ChatMessage] = [:]
    @MainActor private static var lastSeqs: [UUID: Int] = [:]
    @MainActor private static var activeStreams: Set<UUID> = []
    @MainActor private static var streamGenerations: [UUID: UUID] = [:]
    @MainActor private static var producedOutput: Set<UUID> = []
    @MainActor private static var replayKeys: [UUID: Set<String>] = [:]
    @MainActor private static var gitBefore: [UUID: Task<[String: GitChangeDTO], Never>] = [:]

    @MainActor
    static func send(sessionId: UUID, prompt: String, images: [Data], context: ModelContext) {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == sessionId }
        )
        if let session = try? context.fetch(descriptor).first {
            send(session: session, prompt: prompt, images: images, context: context)
        }
    }

    @MainActor
    static func send(session: Session, prompt: String, images: [Data], context: ModelContext) {
        if let endpoint = session.endpoint, let path = session.path {
            if session.isStreaming || activeStreams.contains(session.id) {
                AppLogger.performanceInfo(
                    "queue name=chat.send sessionId=\(session.id.uuidString) images=\(images.count) promptChars=\(prompt.count)"
                )
                _ = ChatActions.addUserMessage(
                    sessionId: session.id, text: prompt, images: images, state: .queued,
                    context: context
                )
            } else {
                ChatNotificationService.requestPermissionOnce()
                AppLogger.performanceInfo(
                    "start name=chat.send sessionId=\(session.id.uuidString) images=\(images.count) promptChars=\(prompt.count)"
                )
                AppLogger.beginInterval("chat.firstToken", key: session.id.uuidString)
                AppLogger.beginInterval("chat.complete", key: session.id.uuidString)
                let userMessage = ChatActions.addUserMessage(
                    sessionId: session.id, text: prompt, images: images, context: context
                )
                begin(
                    message: userMessage, session: session, endpoint: endpoint, path: path,
                    context: context)
            }
        }
    }

    @MainActor
    private static func begin(
        message: ChatMessage, session: Session, endpoint: Endpoint, path: String,
        context: ModelContext
    ) {
        pendingUserMessages[session.id] = message
        SessionActions.setStreaming(true, for: session)
        lastSeqs.removeValue(forKey: session.id)
        producedOutput.remove(session.id)
        activeStreams.insert(session.id)
        let generation = UUID()
        streamGenerations[session.id] = generation
        gitBefore[session.id] = Task {
            await gitStatusMap(endpoint: endpoint, session: session, path: path)
        }
        let existsOnServer = session.existsOnServer
        let sessionId = session.id
        let prompt = message.text
        let images = message.imagesData
        let model = session.model
        let effort = session.effort
        let permissionMode = session.permissionMode
        Task {
            let encodedImages = await encodeForUpload(images)
            var body: [String: Any] = [
                "path": path, "prompt": prompt, "existsOnServer": existsOnServer,
                "permissionMode": permissionMode.rawValue,
            ]
            if !encodedImages.isEmpty { body["images"] = encodedImages }
            if let model { body["model"] = model.rawValue }
            if let effort { body["effort"] = effort.rawValue }
            let stream = StreamingClient.post(
                endpoint: endpoint,
                path: "/sessions/\(sessionId.uuidString)/chat",
                body: body
            )
            await consume(
                stream: stream, sessionId: sessionId, generation: generation, context: context)
        }
    }

    @MainActor
    static func resumeIfStuck(session: Session, context: ModelContext) {
        if activeStreams.contains(session.id) { return }
        guard let endpoint = session.endpoint else { return }
        let stuck = stuckStreaming(sessionId: session.id, context: context)
        if stuck == nil && !session.isStreaming { return }
        let warmSeq = lastSeqs[session.id]
        let afterSeq = warmSeq ?? session.lastSeq
        let isCold = warmSeq == nil
        AppLogger.performanceInfo(
            "start name=chat.resume sessionId=\(session.id.uuidString) stuckMessageId=\(stuck?.id.uuidString ?? "nil") afterSeq=\(afterSeq) cold=\(isCold)"
        )
        if let stuck {
            if isCold {
                let snapshot = ChatLiveStream.snapshot(for: session.id)
                if snapshot.text.isEmpty { snapshot.text = stuck.text }
                stuck.text = ""
            }
            streamingMessages[session.id] = stuck
            if !ChatLiveStream.snapshot(for: session.id).text.isEmpty || stuck.hasToolCalls
                || stuck.hasThinking
            {
                producedOutput.insert(session.id)
            }
        }
        activeStreams.insert(session.id)
        SessionActions.setStreaming(true, for: session)
        let generation = UUID()
        streamGenerations[session.id] = generation
        let sessionId = session.id
        Task {
            let stream = StreamingClient.get(
                endpoint: endpoint,
                path: "/sessions/\(sessionId.uuidString)/chat/resume",
                query: ["after_seq": "\(afterSeq)"]
            )
            await consume(
                stream: stream, sessionId: sessionId, generation: generation, context: context)
        }
    }

    @MainActor
    static func resumeAllStuck(context: ModelContext) {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.isStreaming }
        )
        for session in (try? context.fetch(descriptor)) ?? [] {
            resumeIfStuck(session: session, context: context)
        }
    }

    @MainActor
    static func retry(message: ChatMessage, context: ModelContext) {
        if message.role != .user || message.state != .failed { return }
        let sessionId = message.sessionId
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == sessionId }
        )
        if let session = try? context.fetch(descriptor).first,
            let endpoint = session.endpoint, let path = session.path
        {
            message.state = .retrying
            begin(message: message, session: session, endpoint: endpoint, path: path, context: context)
        }
    }

    @MainActor
    private static func drainQueue(sessionId: UUID, context: ModelContext) {
        let queuedRaw = ChatMessage.State.queued.rawValue
        var queuedDescriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate<ChatMessage> {
                $0.sessionId == sessionId && $0.stateRaw == queuedRaw
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        queuedDescriptor.fetchLimit = 1
        let sessionDescriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == sessionId }
        )
        if let queued = try? context.fetch(queuedDescriptor).first,
            let session = try? context.fetch(sessionDescriptor).first,
            let endpoint = session.endpoint, let path = session.path,
            !session.isStreaming, !activeStreams.contains(sessionId)
        {
            AppLogger.performanceInfo(
                "start name=chat.drainQueue sessionId=\(sessionId.uuidString) promptChars=\(queued.text.count)"
            )
            AppLogger.beginInterval("chat.firstToken", key: sessionId.uuidString)
            AppLogger.beginInterval("chat.complete", key: sessionId.uuidString)
            queued.state = .retrying
            queued.createdAt = .now
            begin(message: queued, session: session, endpoint: endpoint, path: path, context: context)
        }
    }

    @MainActor
    static func abort(sessionId: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == sessionId }
        )
        if let session = try? context.fetch(descriptor).first {
            abort(session: session, context: context)
        }
    }

    @MainActor
    static func abort(session: Session, context: ModelContext) {
        if let endpoint = session.endpoint {
            Task {
                _ = await HTTPClient.post(
                    endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/chat/abort"
                )
            }
        }
        streamGenerations.removeValue(forKey: session.id)
        activeStreams.remove(session.id)
        replayKeys.removeValue(forKey: session.id)
        if let pending = pendingUserMessages.removeValue(forKey: session.id),
            pending.state == .retrying
        {
            pending.state = .failed
        }
        closeStream(sessionId: session.id, isFailed: false, context: context)
        drainQueue(sessionId: session.id, context: context)
    }

    @MainActor
    private static func stuckStreaming(sessionId: UUID, context: ModelContext) -> ChatMessage? {
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate<ChatMessage> {
                $0.sessionId == sessionId && $0.stateRaw == "streaming"
            }
        )
        return try? context.fetch(descriptor).first
    }

    @MainActor
    private static func maybeRename(sessionId: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate<ChatMessage> {
                $0.sessionId == sessionId && $0.roleRaw == "user"
            }
        )
        let count = (try? context.fetchCount(descriptor)) ?? 0
        if count > 0, (count - 1) % 5 == 0 {
            let sessionDescriptor = FetchDescriptor<Session>(
                predicate: #Predicate<Session> { $0.id == sessionId }
            )
            if let session = try? context.fetch(sessionDescriptor).first,
                let endpoint = session.endpoint, let path = session.path
            {
                Task {
                    if let result = await SessionService.generateTitleAndSymbol(
                        endpoint: endpoint, sessionId: sessionId, path: path
                    ) {
                        await MainActor.run {
                            SessionActions.setTitleAndSymbol(
                                result.title, result.symbol, for: session
                            )
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private static func checkpointLastSeq(sessionId: UUID, seq: Int, context: ModelContext) {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == sessionId }
        )
        if let session = try? context.fetch(descriptor).first, seq > session.lastSeq {
            SessionActions.setLastSeq(seq, for: session)
        }
    }

    @MainActor
    private static func markSessionExistsOnServer(sessionId: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == sessionId }
        )
        if let session = try? context.fetch(descriptor).first, !session.existsOnServer {
            SessionActions.markExistsOnServer(session)
        }
    }

    nonisolated private static func encodeForUpload(_ images: [Data]) async -> [[String: String]] {
        await Task.detached {
            let budget = 700_000 / max(images.count, 1)
            return images.compactMap { encode($0, budget: budget) }
        }.value
    }

    nonisolated private static func encode(_ data: Data, budget: Int) -> [String: String]? {
        if let mediaType = passthroughMediaType(data), data.count <= budget {
            return ["data": data.base64EncodedString(), "mediaType": mediaType]
        }
        if let image = UIImage(data: data) {
            for dimension in [2048.0, 1024.0, 512.0] {
                if let jpeg = downscaled(image, maxDimension: dimension).jpegData(compressionQuality: 0.8),
                    jpeg.count <= budget || dimension == 512.0
                {
                    return ["data": jpeg.base64EncodedString(), "mediaType": "image/jpeg"]
                }
            }
        }
        return nil
    }

    nonisolated private static func passthroughMediaType(_ data: Data) -> String? {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if data.starts(with: [0x47, 0x49, 0x46, 0x38]) { return "image/gif" }
        return nil
    }

    nonisolated private static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let scale = min(1, maxDimension / max(image.size.width, image.size.height, 1))
        let size = CGSize(
            width: max(1, (image.size.width * scale).rounded(.down)),
            height: max(1, (image.size.height * scale).rounded(.down))
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    @MainActor
    private static func consume(
        stream: AsyncThrowingStream<Data, Error>, sessionId: UUID, generation: UUID,
        context: ModelContext
    ) async {
        let events = AsyncThrowingStream<ChatStreamEvent, Error> { continuation in
            let task = Task.detached(priority: .userInitiated) { @concurrent in
                do {
                    for try await line in stream {
                        if let event = ChatStreamEvent.decode(line) { continuation.yield(event) }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        do {
            var eventCount = 0
            var sawClose = false
            var sawExit = false
            for try await event in events {
                if streamGenerations[sessionId] != generation { return }
                if let pending = pendingUserMessages.removeValue(forKey: sessionId),
                    pending.state == .retrying
                {
                    pending.state = .complete
                }
                eventCount += 1
                switch event {
                case .result, .aborted, .error: sawClose = true
                case .exited: sawExit = true
                default: break
                }
                let seq = event.seq
                if seq > (lastSeqs[sessionId] ?? -1) { lastSeqs[sessionId] = seq }
                apply(event: event, sessionId: sessionId, context: context)
            }
            if streamGenerations[sessionId] != generation { return }
            AppLogger.performanceInfo(
                "stream closed reason=eof sessionId=\(sessionId.uuidString) events=\(eventCount) terminal=\(sawClose || sawExit)"
            )
            streamGenerations.removeValue(forKey: sessionId)
            activeStreams.remove(sessionId)
            replayKeys.removeValue(forKey: sessionId)
            if eventCount > 0 && !sawClose && !sawExit {
                streamingMessages.removeValue(forKey: sessionId)
                scheduleResume(sessionId: sessionId, context: context)
                return
            }
            AppLogger.endInterval("chat.firstToken", key: sessionId.uuidString)
            AppLogger.endInterval("chat.complete", key: sessionId.uuidString)
            if let pending = pendingUserMessages.removeValue(forKey: sessionId),
                pending.state == .retrying
            {
                pending.state = .failed
            }
            if !sawClose {
                closeStream(sessionId: sessionId, isFailed: false, context: context)
            }
            lastSeqs.removeValue(forKey: sessionId)
            drainQueue(sessionId: sessionId, context: context)
        } catch StreamingError.preHeaders(let underlying) {
            AppLogger.connectionError(
                "stream failed reason=preHeaders sessionId=\(sessionId.uuidString) error=\(underlying)")
            if streamGenerations[sessionId] != generation { return }
            streamGenerations.removeValue(forKey: sessionId)
            activeStreams.remove(sessionId)
            replayKeys.removeValue(forKey: sessionId)
            if let pending = pendingUserMessages.removeValue(forKey: sessionId) {
                pending.state = .failed
            }
            if streamingMessages[sessionId] != nil {
                closeStream(sessionId: sessionId, isFailed: false, context: context)
            } else {
                let descriptor = FetchDescriptor<Session>(
                    predicate: #Predicate<Session> { $0.id == sessionId }
                )
                if let session = try? context.fetch(descriptor).first {
                    SessionActions.setStreaming(false, for: session)
                }
            }
        } catch {
            AppLogger.connectionError(
                "stream closed reason=error sessionId=\(sessionId.uuidString) error=\(error)")
            if streamGenerations[sessionId] != generation { return }
            streamGenerations.removeValue(forKey: sessionId)
            activeStreams.remove(sessionId)
            replayKeys.removeValue(forKey: sessionId)
            streamingMessages.removeValue(forKey: sessionId)
            scheduleResume(sessionId: sessionId, context: context)
        }
    }

    @MainActor
    private static func existingAssistantKeys(sessionId: UUID, context: ModelContext) -> Set<String>
    {
        var descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate<ChatMessage> {
                $0.sessionId == sessionId && $0.roleRaw == "assistant"
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        var keys: Set<String> = []
        for message in (try? context.fetch(descriptor)) ?? [] {
            let messageId = message.id
            let toolDescriptor = FetchDescriptor<ChatToolCall>(
                predicate: #Predicate<ChatToolCall> { $0.messageId == messageId }
            )
            let toolIds = ((try? context.fetch(toolDescriptor)) ?? []).map { $0.id }.sorted()
            keys.insert(message.text + "|" + toolIds.joined(separator: ","))
        }
        return keys
    }

    @MainActor
    private static func scheduleResume(sessionId: UUID, context: ModelContext) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            let descriptor = FetchDescriptor<Session>(
                predicate: #Predicate<Session> { $0.id == sessionId }
            )
            if let session = try? context.fetch(descriptor).first {
                resumeIfStuck(session: session, context: context)
            }
        }
    }

    @MainActor
    private static func ensureStreamingMessage(
        sessionId: UUID, context: ModelContext
    ) -> ChatMessage {
        producedOutput.insert(sessionId)
        if let existing = streamingMessages[sessionId] { return existing }
        let snapshot = ChatLiveStream.snapshot(for: sessionId)
        if !snapshot.hasFirstToken {
            AppLogger.endInterval("chat.firstToken", key: sessionId.uuidString)
            snapshot.hasFirstToken = true
        }
        let message = ChatActions.beginAssistant(sessionId: sessionId, context: context)
        streamingMessages[sessionId] = message
        return message
    }

    @MainActor
    private static func closeStream(sessionId: UUID, isFailed: Bool, context: ModelContext) {
        if let message = streamingMessages.removeValue(forKey: sessionId) {
            let snapshot = ChatLiveStream.peek(for: sessionId)
            let liveText = snapshot?.text ?? ""
            if message.text.isEmpty && !liveText.isEmpty { message.text = liveText }
            if message.thinking.isEmpty, let snapshot {
                message.thinking = snapshot.thinking
                message.thinkingMs = snapshot.thinkingMs
            }
            if message.text.isEmpty && !message.hasToolCalls && !message.hasThinking && !isFailed {
                context.delete(message)
            } else {
                ChatActions.finishStreaming(message, isFailed: isFailed)
            }
        }
        let pendingRaw = ChatToolCall.State.pending.rawValue
        let pendingDescriptor = FetchDescriptor<ChatToolCall>(
            predicate: #Predicate<ChatToolCall> {
                $0.stateRaw == pendingRaw && $0.sessionId == sessionId
            }
        )
        if let pending = try? context.fetch(pendingDescriptor) {
            for call in pending { call.state = .failed }
        }
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == sessionId }
        )
        let produced = producedOutput.remove(sessionId) != nil
        if let session = try? context.fetch(descriptor).first {
            let wasStreaming = session.isStreaming
            SessionActions.setStreaming(false, for: session)
            if wasStreaming && produced { notifyCompletion(session: session, context: context) }
        }
        ChatLiveStream.clear(sessionId: sessionId)
    }

    @MainActor
    private static func gitStatusMap(
        endpoint: Endpoint, session: Session, path: String
    ) async -> [String: GitChangeDTO] {
        let (dto, _) = await GitService.status(endpoint: endpoint, session: session, path: path)
        var map: [String: GitChangeDTO] = [:]
        for change in dto?.changes ?? [] { map[change.path] = change }
        return map
    }

    @MainActor
    private static func captureGitDelta(sessionId: UUID, context: ModelContext) {
        let beforeTask = gitBefore.removeValue(forKey: sessionId)
        let sessionDescriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == sessionId }
        )
        guard let session = try? context.fetch(sessionDescriptor).first,
            let endpoint = session.endpoint, let path = session.path
        else { return }
        var messageDescriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate<ChatMessage> {
                $0.sessionId == sessionId && $0.roleRaw == "assistant"
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        messageDescriptor.fetchLimit = 1
        guard let messageId = (try? context.fetch(messageDescriptor).first)?.id else { return }
        Task {
            let before = await beforeTask?.value ?? [:]
            let after = await gitStatusMap(endpoint: endpoint, session: session, path: path)
            let changes = after.values.filter { change in
                let prior = before[change.path]
                return prior == nil || prior?.additions != change.additions
                    || prior?.deletions != change.deletions
            }
            ChatActions.attachGitDelta(
                messageId: messageId, sessionId: sessionId, changes: Array(changes), context: context)
        }
    }

    @MainActor
    private static func notifyCompletion(session: Session, context: ModelContext) {
        let sessionId = session.id
        var messageDescriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate<ChatMessage> {
                $0.sessionId == sessionId && $0.roleRaw == "assistant"
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        messageDescriptor.fetchLimit = 1
        let snippet = (try? context.fetch(messageDescriptor).first)?.text ?? ""
        if snippet.isEmpty { return }
        let windowDescriptor = FetchDescriptor<Window>(
            predicate: #Predicate<Window> { $0.isFocused }
        )
        let focusedId = (try? context.fetch(windowDescriptor).first)?.session?.id
        if UIApplication.shared.applicationState != .active {
            if focusedId != session.id { session.hasUnread = true }
            ChatNotificationService.postCompletion(
                sessionId: sessionId, title: session.title, snippet: String(snippet.prefix(140)))
            return
        }
        if focusedId == session.id { return }
        session.hasUnread = true
        SessionToastStore.shared.present(
            SessionToast(
                sessionId: sessionId,
                title: session.title,
                symbol: session.symbol,
                snippet: String(snippet.prefix(140))
            )
        )
    }

    @MainActor
    private static func apply(event: ChatStreamEvent, sessionId: UUID, context: ModelContext) {
        switch event {
        case .assistantTextDelta(_, let text):
            if !text.isEmpty {
                _ = ensureStreamingMessage(sessionId: sessionId, context: context)
                let snapshot = ChatLiveStream.snapshot(for: sessionId)
                if snapshot.isThinking {
                    snapshot.isThinking = false
                    if snapshot.thinkingMs == 0, let started = snapshot.thinkingStartedAt {
                        snapshot.thinkingMs = Int(Date().timeIntervalSince(started) * 1000)
                    }
                }
                snapshot.text += text
                snapshot.deltaCount += 1
                snapshot.isCompacting = false
            }
        case .assistantThinkingDelta(_, let text):
            _ = ensureStreamingMessage(sessionId: sessionId, context: context)
            let snapshot = ChatLiveStream.snapshot(for: sessionId)
            if snapshot.thinkingStartedAt == nil { snapshot.thinkingStartedAt = Date() }
            snapshot.isThinking = true
            snapshot.thinking += text
            snapshot.isCompacting = false
        case .compacting:
            _ = ensureStreamingMessage(sessionId: sessionId, context: context)
            ChatLiveStream.snapshot(for: sessionId).isCompacting = true
        case .assistantFinal(
            _, let text, let thinking, let thinkingRedacted, let toolUses, let model,
            let contextTokens):
            if let keys = replayKeys[sessionId],
                keys.contains(text + "|" + toolUses.map(\.id).sorted().joined(separator: ","))
            {
                break
            }
            if let contextTokens {
                SessionActions.setContextUsage(
                    tokens: contextTokens, window: nil, for: sessionId, context: context)
            }
            if !text.isEmpty || !toolUses.isEmpty || streamingMessages[sessionId] != nil {
                let message = ensureStreamingMessage(sessionId: sessionId, context: context)
                let snapshot = ChatLiveStream.snapshot(for: sessionId)
                if snapshot.isThinking {
                    snapshot.isThinking = false
                    if snapshot.thinkingMs == 0, let started = snapshot.thinkingStartedAt {
                        snapshot.thinkingMs = Int(Date().timeIntervalSince(started) * 1000)
                    }
                }
                let resolved = text.isEmpty ? snapshot.text : text
                let resolvedThinking = thinking.isEmpty ? snapshot.thinking : thinking
                ChatActions.completeAssistant(
                    message, finalText: resolved, thinking: resolvedThinking,
                    thinkingMs: snapshot.thinkingMs, thinkingRedacted: thinkingRedacted,
                    toolUses: toolUses, model: model, context: context)
                streamingMessages.removeValue(forKey: sessionId)
                ChatLiveStream.clear(sessionId: sessionId)
                checkpointLastSeq(sessionId: sessionId, seq: event.seq, context: context)
            }
        case .toolResult(_, let toolUseId, let text, let isError):
            ChatActions.applyToolResult(
                toolUseId: toolUseId, text: text, isError: isError, context: context)
        case .result, .aborted, .error:
            AppLogger.endInterval("chat.firstToken", key: sessionId.uuidString)
            AppLogger.endInterval("chat.complete", key: sessionId.uuidString)
            checkpointLastSeq(sessionId: sessionId, seq: event.seq, context: context)
            if case .error = event {
                _ = ensureStreamingMessage(sessionId: sessionId, context: context)
                closeStream(sessionId: sessionId, isFailed: true, context: context)
            } else {
                closeStream(sessionId: sessionId, isFailed: false, context: context)
            }
            if case .result(_, let costUsd, let contextWindow) = event {
                if let costUsd {
                    ChatActions.applyCost(sessionId: sessionId, costUsd: costUsd, context: context)
                }
                if let contextWindow {
                    SessionActions.setContextUsage(
                        tokens: nil, window: contextWindow, for: sessionId, context: context)
                }
                maybeRename(sessionId: sessionId, context: context)
                captureGitDelta(sessionId: sessionId, context: context)
            }
            activeStreams.remove(sessionId)
            drainQueue(sessionId: sessionId, context: context)
        case .replay:
            replayKeys[sessionId] = existingAssistantKeys(sessionId: sessionId, context: context)
        case .initialized:
            markSessionExistsOnServer(sessionId: sessionId, context: context)
        case .exited, .unknown:
            break
        }
    }
}

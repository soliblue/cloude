import Foundation
import SwiftData
import UIKit

enum ChatService {
    @MainActor private static var streamingMessages: [UUID: ChatMessage] = [:]
    @MainActor private static var pendingUserMessages: [UUID: ChatMessage] = [:]
    @MainActor private static var lastSeqs: [UUID: Int] = [:]
    @MainActor private static var activeStreams: Set<UUID> = []
    @MainActor private static var streamGenerations: [UUID: UUID] = [:]

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
            ChatNotificationService.requestPermissionOnce()
            AppLogger.performanceInfo(
                "start name=chat.send sessionId=\(session.id.uuidString) images=\(images.count) promptChars=\(prompt.count)"
            )
            AppLogger.beginInterval("chat.firstToken", key: session.id.uuidString)
            AppLogger.beginInterval("chat.complete", key: session.id.uuidString)
            let userMessage = ChatActions.addUserMessage(
                sessionId: session.id, text: prompt, images: images, context: context
            )
            pendingUserMessages[session.id] = userMessage
            SessionActions.setStreaming(true, for: session)
            lastSeqs.removeValue(forKey: session.id)
            activeStreams.insert(session.id)
            let generation = UUID()
            streamGenerations[session.id] = generation
            let existsOnServer = session.existsOnServer
            let sessionId = session.id
            Task {
                let encodedImages = await encodeForUpload(images)
                var body: [String: Any] = [
                    "path": path, "prompt": prompt, "existsOnServer": existsOnServer,
                ]
                if !encodedImages.isEmpty { body["images"] = encodedImages }
                if let model = session.model { body["model"] = model.rawValue }
                if let effort = session.effort { body["effort"] = effort.rawValue }
                let stream = StreamingClient.post(
                    endpoint: endpoint,
                    path: "/sessions/\(sessionId.uuidString)/chat",
                    body: body
                )
                await consume(
                    stream: stream, sessionId: sessionId, generation: generation, context: context)
            }
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
            pendingUserMessages[sessionId] = message
            SessionActions.setStreaming(true, for: session)
            lastSeqs.removeValue(forKey: sessionId)
            activeStreams.insert(sessionId)
            let generation = UUID()
            streamGenerations[sessionId] = generation
            let prompt = message.text
            let images = message.imagesData
            let existsOnServer = session.existsOnServer
            Task {
                let encodedImages = await encodeForUpload(images)
                var body: [String: Any] = [
                    "path": path, "prompt": prompt, "existsOnServer": existsOnServer,
                ]
                if !encodedImages.isEmpty { body["images"] = encodedImages }
                if let model = session.model { body["model"] = model.rawValue }
                if let effort = session.effort { body["effort"] = effort.rawValue }
                let stream = StreamingClient.post(
                    endpoint: endpoint,
                    path: "/sessions/\(sessionId.uuidString)/chat",
                    body: body
                )
                await consume(
                    stream: stream, sessionId: sessionId, generation: generation, context: context)
            }
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
        if let pending = pendingUserMessages.removeValue(forKey: session.id),
            pending.state == .retrying
        {
            pending.state = .failed
        }
        closeStream(sessionId: session.id, isFailed: false, context: context)
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
        do {
            for try await line in stream {
                if streamGenerations[sessionId] != generation { return }
                if let event = ChatStreamEvent.decode(line) {
                    if let pending = pendingUserMessages.removeValue(forKey: sessionId),
                        pending.state == .retrying
                    {
                        pending.state = .complete
                    }
                    let seq = event.seq
                    if seq > (lastSeqs[sessionId] ?? -1) { lastSeqs[sessionId] = seq }
                    apply(event: event, sessionId: sessionId, context: context)
                }
            }
            if streamGenerations[sessionId] != generation { return }
            AppLogger.performanceInfo(
                "stream closed reason=eof sessionId=\(sessionId.uuidString)")
            AppLogger.endInterval("chat.firstToken", key: sessionId.uuidString)
            AppLogger.endInterval("chat.complete", key: sessionId.uuidString)
            streamGenerations.removeValue(forKey: sessionId)
            activeStreams.remove(sessionId)
            if let pending = pendingUserMessages.removeValue(forKey: sessionId),
                pending.state == .retrying
            {
                pending.state = .failed
            }
            closeStream(sessionId: sessionId, isFailed: false, context: context)
            lastSeqs.removeValue(forKey: sessionId)
        } catch StreamingError.preHeaders(let underlying) {
            AppLogger.connectionError(
                "stream failed reason=preHeaders sessionId=\(sessionId.uuidString) error=\(underlying)")
            if streamGenerations[sessionId] != generation { return }
            streamGenerations.removeValue(forKey: sessionId)
            activeStreams.remove(sessionId)
            streamingMessages.removeValue(forKey: sessionId)
            if let pending = pendingUserMessages.removeValue(forKey: sessionId) {
                pending.state = .failed
            }
            let descriptor = FetchDescriptor<Session>(
                predicate: #Predicate<Session> { $0.id == sessionId }
            )
            if let session = try? context.fetch(descriptor).first {
                SessionActions.setStreaming(false, for: session)
            }
        } catch {
            AppLogger.connectionError(
                "stream closed reason=error sessionId=\(sessionId.uuidString) error=\(error)")
            if streamGenerations[sessionId] != generation { return }
            streamGenerations.removeValue(forKey: sessionId)
            activeStreams.remove(sessionId)
            streamingMessages.removeValue(forKey: sessionId)
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
    }

    @MainActor
    private static func ensureStreamingMessage(
        sessionId: UUID, context: ModelContext
    ) -> ChatMessage {
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
            if message.text.isEmpty && !message.hasToolCalls && !isFailed {
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
        if let session = try? context.fetch(descriptor).first {
            SessionActions.setStreaming(false, for: session)
            notifyCompletion(session: session, context: context)
        }
        ChatLiveStream.clear(sessionId: sessionId)
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
        if UIApplication.shared.applicationState != .active {
            ChatNotificationService.postCompletion(
                title: session.title, snippet: String(snippet.prefix(140)))
            return
        }
        let windowDescriptor = FetchDescriptor<Window>(
            predicate: #Predicate<Window> { $0.isFocused }
        )
        let focusedId = (try? context.fetch(windowDescriptor).first)?.session?.id
        if focusedId == session.id { return }
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
                snapshot.text += text
                snapshot.deltaCount += 1
                snapshot.isCompacting = false
            }
        case .compacting:
            _ = ensureStreamingMessage(sessionId: sessionId, context: context)
            ChatLiveStream.snapshot(for: sessionId).isCompacting = true
        case .assistantFinal(_, let text, let toolUses, let model):
            if !text.isEmpty || !toolUses.isEmpty || streamingMessages[sessionId] != nil {
                let message = ensureStreamingMessage(sessionId: sessionId, context: context)
                let snapshot = ChatLiveStream.snapshot(for: sessionId)
                let resolved = text.isEmpty ? snapshot.text : text
                ChatActions.completeAssistant(
                    message, finalText: resolved, toolUses: toolUses, model: model, context: context)
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
            if case .result(_, let costUsd) = event {
                if let costUsd {
                    ChatActions.applyCost(sessionId: sessionId, costUsd: costUsd, context: context)
                }
                maybeRename(sessionId: sessionId, context: context)
            }
        case .initialized:
            markSessionExistsOnServer(sessionId: sessionId, context: context)
        case .exited, .unknown:
            break
        }
    }
}

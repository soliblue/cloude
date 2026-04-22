import Foundation
import SwiftData
import UIKit

enum ChatService {
    @MainActor private static var streamingMessages: [UUID: ChatMessage] = [:]

    @MainActor
    static func send(session: Session, prompt: String, images: [Data], context: ModelContext) {
        if let endpoint = session.endpoint, let path = session.path {
            AppLogger.performanceInfo(
                "start name=chat.send sessionId=\(session.id.uuidString) images=\(images.count) promptChars=\(prompt.count)"
            )
            AppLogger.beginInterval("chat.firstToken", key: session.id.uuidString)
            AppLogger.beginInterval("chat.complete", key: session.id.uuidString)
            _ = ChatActions.addUserMessage(
                sessionId: session.id, text: prompt, images: images, context: context
            )
            SessionActions.setStreaming(true, for: session)
            let encodedImages = images.compactMap(encode)
            let existsOnServer = session.existsOnServer
            let sessionId = session.id
            Task {
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
                await consume(stream: stream, sessionId: sessionId, context: context)
            }
        }
    }

    @MainActor
    static func resumeIfStuck(session: Session, context: ModelContext) {
        if let endpoint = session.endpoint, let stuck = stuckStreaming(sessionId: session.id, context: context) {
            AppLogger.performanceInfo(
                "start name=chat.resume sessionId=\(session.id.uuidString) stuckMessageId=\(stuck.id.uuidString)"
            )
            for call in stuck.toolCalls { context.delete(call) }
            stuck.text = ""
            streamingMessages[session.id] = stuck
            SessionActions.setStreaming(true, for: session)
            let snapshot = ChatLiveStream.snapshot(for: session.id)
            snapshot.text = ""
            snapshot.deltaCount = 0
            snapshot.hasFirstToken = false
            let sessionId = session.id
            Task {
                let stream = StreamingClient.get(
                    endpoint: endpoint,
                    path: "/sessions/\(sessionId.uuidString)/chat/resume",
                    query: ["after_seq": "-1"]
                )
                await consume(stream: stream, sessionId: sessionId, context: context)
            }
        }
    }

    static func abort(session: Session) {
        if let endpoint = session.endpoint {
            Task {
                _ = await HTTPClient.post(
                    endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/chat/abort"
                )
            }
        }
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
    private static func markSessionExistsOnServer(sessionId: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == sessionId }
        )
        if let session = try? context.fetch(descriptor).first, !session.existsOnServer {
            SessionActions.markExistsOnServer(session)
        }
    }

    private static func encode(_ data: Data) -> [String: String]? {
        if let image = UIImage(data: data), let png = image.pngData() {
            return ["data": png.base64EncodedString(), "mediaType": "image/png"]
        }
        return nil
    }

    @MainActor
    private static func consume(
        stream: AsyncThrowingStream<Data, Error>, sessionId: UUID, context: ModelContext
    ) async {
        do {
            for try await line in stream {
                if let event = ChatStreamEvent.decode(line) {
                    apply(event: event, sessionId: sessionId, context: context)
                }
            }
            AppLogger.performanceInfo(
                "stream closed reason=eof sessionId=\(sessionId.uuidString)")
            AppLogger.endInterval("chat.firstToken", key: sessionId.uuidString)
            AppLogger.endInterval("chat.complete", key: sessionId.uuidString)
            closeStream(sessionId: sessionId, isFailed: false, context: context)
        } catch {
            AppLogger.connectionError(
                "stream closed reason=error sessionId=\(sessionId.uuidString) error=\(error)")
            AppLogger.endInterval("chat.firstToken", key: sessionId.uuidString)
            AppLogger.endInterval("chat.complete", key: sessionId.uuidString)
            closeStream(sessionId: sessionId, isFailed: true, context: context)
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
            if message.text.isEmpty && message.toolCalls.isEmpty {
                context.delete(message)
            } else {
                ChatActions.finishStreaming(message, isFailed: isFailed)
            }
        }
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == sessionId }
        )
        if let session = try? context.fetch(descriptor).first {
            SessionActions.setStreaming(false, for: session)
        }
        ChatLiveStream.clear(sessionId: sessionId)
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
            }
        case .assistantFinal(_, let text, let toolUses):
            if !text.isEmpty || !toolUses.isEmpty || streamingMessages[sessionId] != nil {
                let message = ensureStreamingMessage(sessionId: sessionId, context: context)
                let snapshot = ChatLiveStream.snapshot(for: sessionId)
                let resolved = text.isEmpty ? snapshot.text : text
                ChatActions.completeAssistant(
                    message, finalText: resolved, toolUses: toolUses, context: context)
                streamingMessages.removeValue(forKey: sessionId)
                ChatLiveStream.clear(sessionId: sessionId)
            }
        case .toolResult(_, let toolUseId, let text, let isError):
            ChatActions.applyToolResult(
                toolUseId: toolUseId, text: text, isError: isError, context: context)
        case .result, .aborted, .error:
            AppLogger.endInterval("chat.firstToken", key: sessionId.uuidString)
            AppLogger.endInterval("chat.complete", key: sessionId.uuidString)
            closeStream(sessionId: sessionId, isFailed: false, context: context)
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

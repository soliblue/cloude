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
            let encodedImages = images.compactMap(encode)
            let existsOnServer = session.existsOnServer
            let sessionId = session.id
            Task {
                var body: [String: Any] = [
                    "path": path, "prompt": prompt, "existsOnServer": existsOnServer,
                ]
                if !encodedImages.isEmpty { body["images"] = encodedImages }
                let stream = StreamingClient.post(
                    endpoint: endpoint,
                    path: "/sessions/\(sessionId.uuidString)/chat",
                    body: body
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
    )
        -> ChatMessage
    {
        if let existing = streamingMessages[sessionId] { return existing }
        AppLogger.endInterval("chat.firstToken", key: sessionId.uuidString)
        let message = ChatActions.beginAssistant(sessionId: sessionId, context: context)
        streamingMessages[sessionId] = message
        return message
    }

    @MainActor
    private static func closeStream(sessionId: UUID, isFailed: Bool, context: ModelContext) {
        if let message = streamingMessages.removeValue(forKey: sessionId) {
            if message.text.isEmpty && message.toolCalls.isEmpty {
                context.delete(message)
            } else {
                ChatActions.finishStreaming(message, isFailed: isFailed)
            }
        }
    }

    @MainActor
    private static func apply(event: ChatStreamEvent, sessionId: UUID, context: ModelContext) {
        switch event {
        case .assistantTextDelta(_, let text):
            if !text.isEmpty {
                let message = ensureStreamingMessage(sessionId: sessionId, context: context)
                message.text += text
            }
        case .assistantFinal(_, let text, let toolUses):
            if !text.isEmpty || !toolUses.isEmpty || streamingMessages[sessionId] != nil {
                let message = ensureStreamingMessage(sessionId: sessionId, context: context)
                ChatActions.completeAssistant(
                    message,
                    finalText: text.isEmpty ? message.text : text,
                    toolUses: toolUses,
                    context: context)
                streamingMessages.removeValue(forKey: sessionId)
            }
        case .toolResult(_, let toolUseId, let text, let isError):
            ChatActions.applyToolResult(toolUseId: toolUseId, text: text, isError: isError, context: context)
        case .result, .aborted, .error:
            AppLogger.endInterval("chat.firstToken", key: sessionId.uuidString)
            AppLogger.endInterval("chat.complete", key: sessionId.uuidString)
            closeStream(sessionId: sessionId, isFailed: false, context: context)
        case .initialized:
            markSessionExistsOnServer(sessionId: sessionId, context: context)
        case .exited, .unknown:
            break
        }
    }
}

import Foundation
import SwiftData

struct ChatImageHistoryTests {
    @MainActor static func run(context: ModelContext, endpoint: Endpoint) async throws {
        let session = Session(endpoint: endpoint)
        context.insert(session)
        session.modelRaw = "future-model-selection"
        let item: [String: Any] = [
            "id": "image-saved", "type": "imageGeneration", "status": "completed", "result": "opaque-result",
            "savedPath": "/work/generated.png",
        ]
        let limited: [String: Any] = [
            "id": "image-limit", "type": "imageGeneration", "status": "completed", "result": "",
            "failure": ["type": "usageLimitExceeded", "limitId": "image_generation", "resetsAt": 1_788_800_000],
        ]
        let attachment = Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
        let user: [String: Any] = [
            "id": "user-photo", "type": "userMessage",
            "content": [
                ["type": "text", "text": "Inspect attached photo"],
                ["type": "image", "url": "data:image/png;base64," + attachment.base64EncodedString()],
                ["type": "image", "url": "https://example.invalid/never-fetch.png"],
                ["type": "image", "url": "data:image/png;base64,invalid"],
                ["type": "image", "url": "data:text/plain;base64," + attachment.base64EncodedString()],
            ],
        ]
        let history: [String: Any] = ["turns": [["status": "completed", "items": [user, item, limited]]]]
        await ChatActions.importHistory(history, session: session, context: context)
        await ChatActions.importHistory(history, session: session, context: context)
        let id = session.id
        let calls = try context.fetch(FetchDescriptor<ChatToolCall>(predicate: #Predicate { $0.sessionId == id }))
        precondition(calls.count == 2)
        let assistantMessages = try context.fetch(
            FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.sessionId == id && $0.roleRaw == "assistant" }))
        precondition(assistantMessages.allSatisfy { $0.model == "Codex" })
        let photos = try context.fetch(
            FetchDescriptor<ChatMessage>(
                predicate: #Predicate { $0.sessionId == id && $0.remoteItemId == "user-photo" }))
        precondition(
            photos.count == 1 && photos[0].imagesData.filter { !$0.isEmpty } == [attachment]
                && photos[0].imagesData.count == 4 && photos[0].text == "Inspect attached photo")
        let capped = await ChatHistoryImage.resolve(
            Array(
                repeating: (
                    "image", "data:image/png;base64," + Data(repeating: 0, count: 1_048_576).base64EncodedString()
                ),
                count: 24), sources: [], images: [])
        precondition(capped.images.count == 20 && capped.images.reduce(0) { $0 + $1.count } == 20_971_520)
        let success = calls.first { $0.id.hasSuffix(":image-saved") }!
        let failed = calls.first { $0.id.hasSuffix(":image-limit") }!
        precondition(success.kind == .image && success.state == .succeeded)
        precondition(
            success.shortLabel == "Generated image"
                && success.parsedResult["savedPath"] as? String == "/work/generated.png")
        precondition(failed.state == .failed && failed.parsedResult["failure"] is [String: Any])
        let image = ChatImageGeneration(input: success.parsedInput, result: success.result)
        precondition(image.previewPath(relativeTo: "/work") == "/work/generated.png" && image.result == "opaque-result")
        ChatActions.discardHistory(sessionId: id, context: context)
        let remainingCalls = try context.fetchCount(
            FetchDescriptor<ChatToolCall>(predicate: #Predicate { $0.sessionId == id }))
        let remainingMessages = try context.fetchCount(
            FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.sessionId == id }))
        precondition(remainingCalls == 0 && remainingMessages == 0)
        print(
            "PASS native image history preserves bounded inline photos, full result, saved path and quota failure, deduplicates refresh and cleans canceled imports"
        )
    }
}

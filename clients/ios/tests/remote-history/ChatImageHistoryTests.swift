import Foundation
import SwiftData

struct ChatImageHistoryTests {
    @MainActor static func run(context: ModelContext, endpoint: Endpoint) async throws {
        let session = Session(endpoint: endpoint)
        context.insert(session)
        let item: [String: Any] = [
            "id": "image-saved", "type": "imageGeneration", "status": "completed", "result": "opaque-result",
            "savedPath": "/work/generated.png",
        ]
        let limited: [String: Any] = [
            "id": "image-limit", "type": "imageGeneration", "status": "completed", "result": "",
            "failure": ["type": "usageLimitExceeded", "limitId": "image_generation", "resetsAt": 1_788_800_000],
        ]
        let history: [String: Any] = ["turns": [["status": "completed", "items": [item, limited]]]]
        await ChatActions.importHistory(history, session: session, context: context)
        await ChatActions.importHistory(history, session: session, context: context)
        let id = session.id
        let calls = try context.fetch(FetchDescriptor<ChatToolCall>(predicate: #Predicate { $0.sessionId == id }))
        precondition(calls.count == 2)
        let success = calls.first { $0.id.hasSuffix(":image-saved") }!
        let failed = calls.first { $0.id.hasSuffix(":image-limit") }!
        precondition(success.kind == .image && success.state == .succeeded)
        precondition(
            success.shortLabel == "Generated image"
                && success.parsedResult["savedPath"] as? String == "/work/generated.png")
        precondition(failed.state == .failed && failed.parsedResult["failure"] is [String: Any])
        let image = ChatImageGeneration(input: success.parsedInput, result: success.result)
        precondition(image.previewPath(relativeTo: "/work") == "/work/generated.png" && image.result == "opaque-result")
        print("PASS native image history preserves full result, saved path and quota failure, deduplicates refresh")
    }
}

import Foundation
import SwiftData

@main struct DraftCleanupTests {
    @MainActor static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let disk = ChatDraftDisk(root: root)
        ChatDraftService.disk = disk
        let container = try ModelContainer(
            for: Session.self, Endpoint.self, ChatMessage.self, Window.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let cold = Session()
        context.insert(cold)
        try await disk.write(ChatDraft(text: "Unopened saved draft"), sessionId: cold.id, revision: 0)
        let coldCleanup = SessionActions.deleteIfEmpty(cold, context: context)
        await coldCleanup.value
        precondition(cold.modelContext != nil, "Cold unopened saved draft preserves session")
        let reopened = Session()
        context.insert(reopened)
        let cleanup = SessionActions.deleteIfEmpty(reopened, context: context)
        context.insert(Window(session: reopened))
        await cleanup.value
        precondition(reopened.modelContext != nil, "Task reopened while awaiting draft cannot be deleted")
        let messaged = Session()
        context.insert(messaged)
        let messageCleanup = SessionActions.deleteIfEmpty(messaged, context: context)
        context.insert(ChatMessage(sessionId: messaged.id))
        await messageCleanup.value
        precondition(messaged.modelContext != nil, "Message created during cleanup preserves task")
        let remote = Session()
        remote.existsOnServer = true
        remote.codexThreadId = "empty-native-task"
        remote.remoteHistoryPagingInitialized = true
        remote.remoteHistoryOlderCursor = "earlier-empty-turns"
        context.insert(remote)
        await SessionActions.deleteIfEmpty(remote, context: context).value
        precondition(remote.modelContext != nil, "Remote task with empty or unsupported turns remains available")
        let empty = Session()
        context.insert(empty)
        await SessionActions.deleteIfEmpty(empty, context: context).value
        try context.save()
        let surviving = try context.fetch(FetchDescriptor<Session>())
        precondition(!surviving.contains { $0.id == empty.id }, "Unused closed task is still cleaned up")
        print(
            "PASS draft cleanup: cold unopened draft, reopened window and new-message race guards, unused task deletion"
        )
    }
}

import Foundation
import SwiftData

@main struct ChatCompletionTests {
    @MainActor static func main() throws {
        let container = try ModelContainer(
            for: Session.self, Window.self, ChatMessage.self, ChatToolCall.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let session = Session()
        context.insert(session)
        let other = Session()
        context.insert(other)
        let window = Window(session: other, isFocused: true)
        context.insert(window)
        let store = ChatInteractionStore.shared
        store.updateAgent(threadId: "helper", requestId: "helper-approval", pending: true, sessionId: session.id)
        _ = store.add(
            ChatInteraction(id: "parent-approval", method: "approval", paramsJSON: "{}"), sessionId: session.id)
        let agentRevision = store.agentRevisions[session.id, default: 0]
        let revision = store.revisions[session.id, default: 0]
        session.needsAttention = true
        let message = ChatMessage(sessionId: session.id, role: .assistant, state: .streaming)
        message.hasToolCalls = true
        context.insert(message)
        context.insert(ChatToolCall(sessionId: session.id))
        ChatService.streamingMessages[session.id] = message
        ChatService.producedOutput.insert(session.id)
        ChatService.closeStream(sessionId: session.id, isFailed: false, context: context)
        precondition(!session.isStreaming && session.needsAttention && session.hasUnread)
        precondition(store.agentRequests[session.id]?.first?.threadId == "helper")
        precondition(store.agentRevisions[session.id] == agentRevision)
        precondition(store.requests[session.id] == nil && store.revisions[session.id] == revision + 1)
        precondition(!store.replace([], sessionId: session.id, revision: revision))
        precondition(message.state == .complete)
        precondition(SessionToastStore.shared.current?.snippet == "Task finished")
        SessionToastStore.shared.dismiss()
        ChatService.closeStream(sessionId: session.id, isFailed: false, context: context)
        precondition(SessionToastStore.shared.current == nil)
        store.clear(sessionId: session.id)
        precondition(!store.hasAttention(sessionId: session.id))
        let image = ChatMessage(sessionId: session.id, role: .assistant, images: [Data([1, 2, 3])], state: .streaming)
        context.insert(image)
        ChatService.streamingMessages[session.id] = image
        ChatService.producedOutput.insert(session.id)
        session.isStreaming = true
        ChatService.closeStream(sessionId: session.id, isFailed: false, context: context)
        precondition(image.modelContext != nil && image.state == .complete)
        precondition(!session.needsAttention)
        SessionToastStore.shared.dismiss()
        session.hasUnread = false
        window.session = session
        let visibilityId = UUID()
        ChatVisibilityStore.set(session.id, for: visibilityId)
        UIApplication.shared.applicationState = .active
        ChatService.notifyCompletion(session: session, context: context)
        precondition(!session.hasUnread && SessionToastStore.shared.current == nil)
        let presentationId = UUID()
        ChatVisibilityStore.cover(session.id, for: presentationId)
        ChatService.notifyCompletion(session: session, context: context)
        precondition(session.hasUnread && SessionToastStore.shared.current != nil)
        SessionToastStore.shared.dismiss()
        session.hasUnread = false
        ChatVisibilityStore.cover(nil, for: presentationId)
        ChatVisibilityStore.set(nil, for: visibilityId)
        ChatService.notifyCompletion(session: session, context: context)
        precondition(session.hasUnread && SessionToastStore.shared.current != nil)
        SessionToastStore.shared.dismiss()
        session.hasUnread = false
        ChatVisibilityStore.set(session.id, for: visibilityId)
        UIApplication.shared.applicationState = .background
        ChatService.notifyCompletion(session: session, context: context)
        precondition(session.hasUnread && ChatNotificationService.notifications.last?.2 == "Task finished")
        UIApplication.shared.applicationState = .inactive
        session.hasUnread = false
        image.text = "  \n "
        ChatService.notifyCompletion(session: session, context: context, isFailed: true)
        precondition(session.hasUnread && ChatNotificationService.notifications.last?.2 == "Task ended with an error")
        UIApplication.shared.applicationState = .active
        window.session = other
        ChatVisibilityStore.set(nil, for: visibilityId)
        image.text = String(repeating: "x", count: 200)
        ChatService.notifyCompletion(session: session, context: context)
        precondition(SessionToastStore.shared.current?.snippet == String(repeating: "x", count: 140))
        SessionToastStore.shared.dismiss()
        try context.save()
        print(
            "PASS helper attention survives parent completion, stale approvals fenced, tool/image-only unread, focused/background behavior, bounded snippets and duplicate completion suppression"
        )
    }
}

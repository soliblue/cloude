import Foundation
import SwiftData

@main struct SteerTests {
    @MainActor static func main() async throws {
        let container = try ModelContainer(
            for: Session.self, Endpoint.self, ChatMessage.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let endpoint = Endpoint()
        let session = Session(endpoint: endpoint)
        context.insert(endpoint)
        context.insert(session)
        let message = ChatMessage(
            sessionId: session.id, role: .user, text: "Keep literal --flag \"quote\"", state: .queued)
        context.insert(message)
        let first = await ChatService.steer(message: message, context: context)
        precondition(!first && message.state == .queued)
        HTTPClient.respond = true
        let retried = await ChatService.steer(message: message, context: context)
        precondition(retried && message.state == .complete)
        precondition(HTTPClient.bodies.count == 2)
        for body in HTTPClient.bodies {
            precondition(body["requestId"] as? String == message.id.uuidString)
            precondition(body["prompt"] as? String == message.text)
        }
        let repeated = await ChatService.steer(message: message, context: context)
        precondition(!repeated && HTTPClient.bodies.count == 2)
        let next = ChatMessage(sessionId: session.id, role: .user, text: "New steer", state: .queued)
        context.insert(next)
        let second = await ChatService.steer(message: next, context: context)
        precondition(second && HTTPClient.bodies.last?["requestId"] as? String == next.id.uuidString)
        print(
            "PASS steering: ambiguous response retains queue, retry reuses exact persisted message ID/prompt, accepted item cannot resend, distinct message has distinct ID"
        )
    }
}

import Foundation
import SwiftData

@main struct PlanTests {
    @MainActor static func main() throws {
        let container = try ModelContainer(
            for: ChatMessage.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let session = UUID()
        let other = UUID()
        precondition(
            ChatPlanActions.apply(
                itemId: "first", text: "", delta: false, completed: false, seq: 1, sessionId: session, context: context)
        )
        precondition(
            ChatPlanActions.apply(
                itemId: "first", text: "Preview ", delta: true, completed: false, seq: 2, sessionId: session,
                context: context))
        precondition(
            ChatPlanActions.apply(
                itemId: "second", text: "Separate", delta: true, completed: false, seq: 3, sessionId: session,
                context: context))
        precondition(
            ChatPlanActions.apply(
                itemId: "first", text: "🧑🏽‍💻", delta: true, completed: false, seq: 4, sessionId: session, context: context)
        )
        precondition(
            !ChatPlanActions.apply(
                itemId: "first", text: "duplicate", delta: true, completed: false, seq: 4, sessionId: session,
                context: context))
        let first = try! context.fetch(FetchDescriptor<ChatMessage>()).first { $0.remoteItemId == "first" }!
        precondition(first.text == "Preview 🧑🏽‍💻" && first.planIsComplete == false)
        precondition(
            ChatPlanActions.apply(
                itemId: "first", text: "Authoritative final", delta: false, completed: true, seq: 5, sessionId: session,
                context: context))
        precondition(first.text == "Authoritative final" && first.planIsComplete == true)
        precondition(
            !ChatPlanActions.apply(
                itemId: "first", text: "late delta", delta: true, completed: false, seq: 6, sessionId: session,
                context: context))
        precondition(
            ChatPlanActions.apply(
                itemId: "first", text: "Other session", delta: false, completed: false, seq: 1, sessionId: other,
                context: context))
        ChatPlanActions.finish(sessionId: session, isFailed: true, context: context)
        let second = try! context.fetch(FetchDescriptor<ChatMessage>()).first { $0.remoteItemId == "second" }!
        precondition(second.text == "Separate" && second.planIsComplete == true && second.state == .failed)
        precondition(first.state == .complete)
        precondition(
            try! context.fetch(FetchDescriptor<ChatMessage>()).first { $0.sessionId == other }!.planIsComplete == false)
        try context.save()
        let restored = ModelContext(container)
        precondition(
            !ChatPlanActions.apply(
                itemId: "first", text: "replayed", delta: true, completed: false, seq: 4, sessionId: session,
                context: restored))
        precondition(
            try! restored.fetch(FetchDescriptor<ChatMessage>()).first {
                $0.sessionId == session && $0.remoteItemId == "first"
            }!.text == "Authoritative final")
        let start = ContinuousClock.now
        for sequence in 1...2000 {
            ChatPlanActions.apply(
                itemId: "stress", text: "x", delta: true, completed: false, seq: sequence, sessionId: session,
                context: context)
        }
        let elapsed = start.duration(to: .now)
        precondition(
            try! context.fetch(FetchDescriptor<ChatMessage>()).first { $0.remoteItemId == "stress" }!.text.count == 2000
        )
        print(
            "PASS plan item isolation, exact Unicode deltas, authoritative replacement, duplicate/restart replay, late deltas and interrupted partial plans; 2000 deltas: \(elapsed)"
        )
    }
}

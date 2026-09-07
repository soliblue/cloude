import Foundation
import SwiftData

@main struct PlanImplementationTests {
    @MainActor static func main() throws {
        let container = try ModelContainer(
            for: Session.self, Endpoint.self, ChatMessage.self, Window.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let endpoint = Endpoint()
        let session = Session(endpoint: endpoint, path: "/work")
        session.provider = .codex
        context.insert(endpoint)
        context.insert(session)
        let plan = ChatMessage(
            sessionId: session.id, role: .assistant, text: "  Selected old plan\n1. Keep --literal \"quotes\"\n")
        plan.planIsComplete = true
        context.insert(plan)
        ChatDraftStore.setText("Unsent unrelated draft", for: session.id)
        ChatDraftStore.setImages([Data([1, 2, 3])], for: session.id)
        ChatDraftStore.setPastedTexts(["Pasted work"], for: session.id)
        ChatDraftStore.addReference(
            ChatReference(name: "README", path: "/work/README", kind: "mention"), for: session.id)
        let draft = ChatDraftStore.snapshot(for: session.id)
        session.permissionMode = .plan
        precondition(ChatPlanService.canImplement(plan, session: session))
        ChatService.onSend = { precondition(!ChatPlanService.implement(plan, session: session, context: context)) }
        precondition(ChatPlanService.implement(plan, session: session, context: context))
        precondition(
            ChatService.count == 1 && ChatService.permissions == .standard && session.permissionMode == .standard)
        precondition(ChatService.prompt == "Implement this selected plan:\n\n" + plan.text)
        precondition(
            !ChatPlanService.implement(plan, session: session, context: context),
            "Rapid second tap is blocked by active turn")
        precondition(
            ChatDraftStore.snapshot(for: session.id) == draft,
            "Implementation never changes composer draft or attachments")
        ChatService.onSend = nil
        session.isStreaming = false
        session.permissionMode = .bypassPermissions
        ChatService.accept = false
        precondition(!ChatPlanService.implement(plan, session: session, context: context))
        precondition(
            session.permissionMode == .bypassPermissions && ChatService.permissions == .standard,
            "Rejected send rolls permissions back")
        session.remoteIsRunning = true
        precondition(!ChatPlanService.canImplement(plan, session: session))
        session.remoteIsRunning = false
        plan.state = .failed
        precondition(!ChatPlanService.isCompletedPlan(plan, session: session))
        plan.state = .complete
        plan.planIsComplete = false
        precondition(!ChatPlanService.canImplement(plan, session: session))
        plan.planIsComplete = true
        plan.text = " \n"
        precondition(!ChatPlanService.canImplement(plan, session: session))
        plan.text = "Plan"
        session.provider = .claude
        precondition(!ChatPlanService.canImplement(plan, session: session))
        session.provider = .codex
        session.path = "relative"
        precondition(!ChatPlanService.canImplement(plan, session: session))
        session.path = "/work"
        endpoint.host = ""
        precondition(!ChatPlanService.canImplement(plan, session: session))
        endpoint.host = "remote.example"
        session.endpoint = nil
        precondition(!ChatPlanService.canImplement(plan, session: session))
        precondition(ChatDraftStore.snapshot(for: session.id) == draft)
        print(
            "PASS implement plan: exact selected plan/default permissions, draft preservation, duplicate/reentrant tap guards, rejected-send rollback, provider/completion/connection/active-turn validation"
        )
    }
}

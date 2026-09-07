import Foundation
import SwiftData

@main struct SessionReviewTests {
    @MainActor static func main() async {
        let container = try! ModelContainer(
            for: Session.self, Endpoint.self, ChatMessage.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let endpoint = Endpoint()
        let session = Session(endpoint: endpoint, path: "/repo", title: "Keep title")
        session.provider = .codex
        session.modelRaw = "gpt-5.5"
        session.effort = .high
        session.tab = .git
        container.mainContext.insert(session)
        let store = SessionReviewStore()
        precondition(store.target.type == .uncommittedChanges && store.canRun(session: session))
        precondition(store.target.parameters.count == 1 && store.target.prompt.contains("untracked"))
        precondition(SessionReviewService.run(session: session, store: store, context: container.mainContext))
        precondition(
            ChatService.sent?.type == .uncommittedChanges && ChatService.sessionId == session.id && session.tab == .chat
        )
        precondition(session.title == "Keep title" && session.modelRaw == "gpt-5.5" && session.effort == .high)
        store.kind = .baseBranch
        precondition(!store.canRun(session: session))
        store.branches.apply(
            SessionWorktreeBranches(branches: [.init(name: "feature", current: true)], defaultBranch: "origin/main"))
        precondition(store.canRun(session: session) && store.target.parameters["branch"] as? String == "origin/main")
        precondition(store.target.prompt.contains("origin/main"))
        store.kind = .commit
        for sha in ["", "main", "HEAD~1", "12", "aaaa;ls", String(repeating: "a", count: 65)] {
            store.sha = sha
            precondition(!store.canRun(session: session))
        }
        store.sha = " ABCDEF1234 \n"
        precondition(store.canRun(session: session) && store.target.parameters["sha"] as? String == "ABCDEF1234")
        let commit = store.target
        store.kind = .custom
        store.instructions = "  "
        precondition(!store.canRun(session: session))
        store.instructions = "Audit the retry logic for duplicate requests."
        precondition(
            store.canRun(session: session) && store.target.parameters["instructions"] as? String == store.instructions)
        precondition(store.target.prompt.contains(store.instructions))
        let message = ChatMessage(
            sessionId: session.id, role: .user, text: commit.prompt, state: .failed, reviewTarget: commit)
        container.mainContext.insert(message)
        try! container.mainContext.save()
        precondition(
            message.reviewTarget == commit && message.reviewTarget?.parameters["sha"] as? String == "ABCDEF1234")
        precondition(try! JSONDecoder().decode(ChatReviewTarget.self, from: message.reviewTargetData!) == commit)
        session.isStreaming = true
        precondition(!store.canRun(session: session))
        session.isStreaming = false
        session.remoteIsRunning = true
        precondition(!store.canRun(session: session))
        session.remoteIsRunning = false
        session.provider = .claude
        precondition(!store.canRun(session: session))
        session.provider = .codex
        endpoint.capabilities = []
        precondition(!store.canRun(session: session))
        endpoint.capabilities = ["codexReview"]
        ChatService.accept = false
        precondition(
            !SessionReviewService.run(session: session, store: store, context: container.mainContext)
                && store.error != nil)
        let unrelatedFields = ChatReviewTarget(
            type: .uncommittedChanges, branch: "ignored", sha: "ignored", instructions: "ignored")
        precondition(unrelatedFields.parameters.count == 1)
        print(
            "PASS review target validation/exact wire shape, selected remote base, readable prompts, saved retry metadata, same task/model/history and active/provider/capability guards"
        )
    }
}

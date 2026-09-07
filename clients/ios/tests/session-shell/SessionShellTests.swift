import Foundation
import SwiftData

@main struct SessionShellTests {
    @MainActor static func main() throws {
        let container = try ModelContainer(
            for: Session.self, Endpoint.self, ChatMessage.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let endpoint = Endpoint()
        let session = Session(endpoint: endpoint, path: "/actual/remote/repo", title: "Keep task")
        session.provider = .codex
        session.modelRaw = "gpt-5.6-luna"
        session.tab = .git
        container.mainContext.insert(session)
        let store = SessionShellStore()
        precondition(!store.canRun(session: session))
        for invalid in [
            "", " \n\t", "a\0b", String(repeating: "a", count: 16_385), String(repeating: "😀", count: 8193),
        ] {
            store.command = invalid
            precondition(!store.canRun(session: session))
        }
        precondition(ChatShellCommand(rawValue: String(repeating: "a", count: 16_384)).isValid)
        store.command = "  printf '%s\\n' '$HOME' | sed 's/HOME/PATH/' > /tmp/result\n"
        let command = ChatShellCommand(rawValue: store.command)
        precondition(store.canRun(session: session))
        precondition(
            command.canSend(
                provider: .codex, hasReview: false, hasImages: false, hasReferences: false, capabilities: ["codexShell"]
            ))
        for flags in [(true, false, false), (false, true, false), (false, false, true)] {
            precondition(
                !command.canSend(
                    provider: .codex, hasReview: flags.0, hasImages: flags.1, hasReferences: flags.2,
                    capabilities: ["codexShell"]))
        }
        precondition(
            !command.canSend(
                provider: .claude, hasReview: false, hasImages: false, hasReferences: false,
                capabilities: ["codexShell"]))
        precondition(
            !command.canSend(
                provider: .codex, hasReview: false, hasImages: false, hasReferences: false, capabilities: []))
        precondition(SessionShellService.run(session: session, store: store, context: container.mainContext))
        precondition(
            ChatService.command == store.command && ChatService.text == command.prompt
                && ChatService.sessionId == session.id)
        precondition(session.tab == .chat && session.title == "Keep task" && session.modelRaw == "gpt-5.6-luna")
        let message = ChatMessage(
            sessionId: session.id, role: .user, text: command.prompt, state: .failed, shellCommand: store.command)
        container.mainContext.insert(message)
        try container.mainContext.save()
        let fresh = ModelContext(container)
        let saved = try fresh.fetch(FetchDescriptor<ChatMessage>()).first!
        precondition(saved.shellCommand == store.command && saved.state == .failed && saved.reviewTarget == nil)
        saved.state = .queued
        try fresh.save()
        precondition(
            try! ModelContext(container).fetch(FetchDescriptor<ChatMessage>()).first!.shellCommand == store.command)
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
        endpoint.capabilities = ["codexShell"]
        ChatService.accept = false
        precondition(
            !SessionShellService.run(session: session, store: store, context: container.mainContext)
                && store.error != nil)
        print(
            "PASS command syntax preserved, UTF16 bounds, exclusive Codex capability validation, same task dispatch, durable retry/queue metadata and idle guards"
        )
    }
}

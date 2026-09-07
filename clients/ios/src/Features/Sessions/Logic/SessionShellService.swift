import Foundation
import SwiftData

@MainActor enum SessionShellService {
    static func run(session: Session, store: SessionShellStore, context: ModelContext) -> Bool {
        if store.canRun(session: session),
            ChatService.send(
                session: session, prompt: ChatShellCommand(rawValue: store.command).prompt, images: [],
                shellCommand: store.command, context: context)
        {
            SessionActions.setTab(.chat, for: session)
            return true
        }
        store.error = "Could not start this command. Check the task connection and wait for any active turn to finish."
        return false
    }
}

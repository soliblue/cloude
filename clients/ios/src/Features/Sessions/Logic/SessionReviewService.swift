import Foundation
import SwiftData

@MainActor enum SessionReviewService {
    static func run(session: Session, store: SessionReviewStore, context: ModelContext) -> Bool {
        if store.canRun(session: session),
            ChatService.send(
                session: session, prompt: store.target.prompt, images: [], reviewTarget: store.target, context: context)
        {
            SessionActions.setTab(.chat, for: session)
            return true
        }
        store.error = "Could not start this review. Check the task connection and wait for any active turn to finish."
        return false
    }
}

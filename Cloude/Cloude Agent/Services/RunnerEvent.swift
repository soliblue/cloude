import Foundation
import CloudeShared

enum RunnerEvent {
    case output(String)
    case sessionId(String)
    case toolCall(name: String, input: String?, toolId: String, parentToolId: String?)
    case runStats(durationMs: Int, costUsd: Double)
    case complete
}

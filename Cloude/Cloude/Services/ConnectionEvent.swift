import Foundation
import CloudeShared

enum ConnectionEvent {
    case directoryListing(path: String, entries: [FileEntry])
    case fileContent(path: String, data: String, mimeType: String, size: Int64)
    case missedResponse(sessionId: String, text: String, completedAt: Date)
    case gitStatus(GitStatusInfo)
    case gitDiff(path: String, diff: String)
    case disconnect(conversationId: UUID, output: ConversationOutput)
    case transcription(String)
    case heartbeatConfig(intervalMinutes: Int?, unreadCount: Int, sessionId: String?)
    case heartbeatOutput(String)
    case heartbeatComplete(String)
    case memories([MemorySection])
}

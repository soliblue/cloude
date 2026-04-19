import Foundation

public struct AttachedFilePayload: Codable {
    public let name: String
    public let data: String

    public init(name: String, data: String) {
        self.name = name
        self.data = data
    }
}

public enum ClientMessage: Codable {
    case chat(message: String, workingDirectory: String?, sessionId: String?, isNewSession: Bool, imagesBase64: [String]?, filesBase64: [AttachedFilePayload]?, conversationId: String?, conversationName: String?, forkSession: Bool, effort: String?, model: String?)
    case abort(conversationId: String?)
    case auth(token: String)
    case listDirectory(path: String)
    case getFile(path: String)
    case getFileFullQuality(path: String)
    case resumeFrom(sessionId: String, lastSeq: Int)
    case gitStatus(path: String)
    case gitDiff(path: String, file: String?, staged: Bool)
    case gitCommit(path: String, message: String, files: [String])
    case gitLog(path: String, count: Int)
    case transcribe(audioBase64: String)
    case getProcesses
    case killProcess(pid: Int32)
    case syncHistory(sessionId: String, workingDirectory: String)
    case searchFiles(query: String, workingDirectory: String)
    case suggestName(text: String, context: [String], conversationId: String)
    case ping(sentAt: Double)

    enum CodingKeys: String, CodingKey {
        case type, message, workingDirectory, token, path, sessionId, isNewSession, file, files, imageBase64, imagesBase64, filesBase64, audioBase64, conversationId, conversationName, pid, forkSession, query, effort, model, text, context, stage, filename, content, staged, sentAt, count, lastSeq
    }
}

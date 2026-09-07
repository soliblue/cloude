import Foundation
import SwiftData

@MainActor
enum ChatHistoryImageService {
    static func load(source: String, message: ChatMessage, session: Session, context: ModelContext) async -> Bool {
        if let index = message.imageSources?.firstIndex(of: source), message.imagesData.indices.contains(index),
            !message.imagesData[index].isEmpty
        {
            return true
        }
        let connection = session.connectionKey
        let remaining = 20_971_520 - message.imagesData.reduce(0) { $0 + $1.count }
        if !Task.isCancelled, !message.isDeleted, !session.isDeleted, message.modelContext === context,
            session.modelContext === context, message.sessionId == session.id,
            ChatHistoryImage.validPath(source), message.imageSources?.contains(source) == true,
            remaining > 0, let endpoint = session.endpoint, !endpoint.isDeleted
        {
            let cacheId = endpoint.cacheId
            if let file = await FileCache.shared.cached(endpoint: cacheId, path: source),
                await FileCache.shared.size(at: file) <= remaining,
                let data = await FileCache.shared.data(at: file, limit: remaining),
                await ChatHistoryImage.validRaster(data), !Task.isCancelled,
                !message.isDeleted, !session.isDeleted, message.modelContext === context,
                session.modelContext === context, session.connectionKey == connection,
                !endpoint.isDeleted, endpoint.cacheId == cacheId, message.imageSources?.contains(source) == true
            {
                return ChatActions.attachRemoteImage(data, source: source, to: message, context: context)
            }
            if !Task.isCancelled, session.connectionKey == connection,
                let (data, response) = await HTTPClient.downloadBounded(
                    endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/files/read",
                    query: ["path": source], maximumBytes: remaining),
                response.statusCode == 200
                    || (response.statusCode == 206
                        && response.value(forHTTPHeaderField: "Content-Range")
                            == "bytes 0-\(data.count - 1)/\(data.count)"),
                data.count <= remaining, await ChatHistoryImage.validRaster(data),
                !Task.isCancelled, !message.isDeleted, !session.isDeleted, message.modelContext === context,
                session.modelContext === context, session.connectionKey == connection,
                !endpoint.isDeleted, endpoint.cacheId == cacheId, message.imageSources?.contains(source) == true
            {
                await FileCache.shared.store(data, endpoint: cacheId, path: source, category: "files")
                if !Task.isCancelled, !message.isDeleted, !session.isDeleted, message.modelContext === context,
                    session.modelContext === context, session.connectionKey == connection,
                    !endpoint.isDeleted, endpoint.cacheId == cacheId, message.imageSources?.contains(source) == true
                {
                    return ChatActions.attachRemoteImage(data, source: source, to: message, context: context)
                }
                if endpoint.cacheId != cacheId || endpoint.isDeleted {
                    await FileCache.shared.remove(endpoint: cacheId)
                }
            }
        }
        return false
    }
}

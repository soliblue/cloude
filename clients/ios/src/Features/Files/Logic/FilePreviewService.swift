import Foundation

enum FilePreviewService {
    static func cached(session: Session, node: FileNodeDTO) async -> FilePreviewResource? {
        if let endpoint = session.endpoint,
            let url = await FileCache.shared.cached(endpoint: endpoint.cacheId, path: node.path)
        {
            return await resource(url: url, node: node, cached: true)
        }
        return nil
    }

    static func load(session: Session, node: FileNodeDTO) async -> FilePreviewResource? {
        if let endpoint = session.endpoint {
            let cacheId = endpoint.cacheId
            if let (file, response) = await HTTPClient.downloadFile(
                endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/files/read", query: ["path": node.path]
            ) {
                if !Task.isCancelled, endpoint.cacheId == cacheId, response.statusCode == 200,
                    let url = await FileCache.shared.store(file, endpoint: cacheId, path: node.path)
                {
                    return await resource(url: url, node: node, cached: false)
                }
                try? FileManager.default.removeItem(at: file)
            }
            if !Task.isCancelled, endpoint.cacheId == cacheId,
                let url = await FileCache.shared.cached(endpoint: cacheId, path: node.path)
            {
                return await resource(url: url, node: node, cached: true)
            }
        }
        return nil
    }

    private static func resource(url: URL, node: FileNodeDTO, cached: Bool) async -> FilePreviewResource {
        switch FilePreviewContentType.detect(for: node) {
        case .audio, .video, .pdf, .binary:
            return FilePreviewResource(url: url, data: nil, isCached: cached, isTruncated: false)
        case .image, .gif:
            return FilePreviewResource(
                url: url, data: await FileCache.shared.data(at: url, limit: 20_971_520), isCached: cached,
                isTruncated: await FileCache.shared.size(at: url) > 20_971_520)
        default:
            return FilePreviewResource(
                url: url, data: await FileCache.shared.data(at: url), isCached: cached,
                isTruncated: await FileCache.shared.size(at: url) > 1_048_576)
        }
    }
}

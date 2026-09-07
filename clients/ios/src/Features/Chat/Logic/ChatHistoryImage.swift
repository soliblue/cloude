import Foundation

enum ChatHistoryImage {
    @concurrent
    static func decode(_ urls: [String]) async -> [Data] {
        var images: [Data] = []
        var remaining = 20_971_520
        for url in urls.prefix(20) where !Task.isCancelled {
            if url.utf8.count <= remaining * 4 / 3 + 128,
                let comma = url.firstIndex(of: ","),
                url[..<comma].lowercased().hasPrefix("data:image/"),
                url[..<comma].lowercased().hasSuffix(";base64"),
                let data = Data(base64Encoded: String(url[url.index(after: comma)...])),
                !data.isEmpty, data.count <= remaining
            {
                images.append(data)
                remaining -= data.count
            }
        }
        return images
    }
}

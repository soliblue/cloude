import Foundation

nonisolated struct ChatWebSource: Identifiable {
    let url: URL
    let title: String
    var id: String { url.absoluteString }

    static func collect(_ value: Any) -> [ChatWebSource] {
        if let object = value as? [String: Any] {
            var sources: [ChatWebSource] = []
            if let raw = object["url"] as? String, let url = URL(string: raw),
                ["https", "http"].contains(url.scheme ?? "")
            {
                sources.append(ChatWebSource(url: url, title: object["title"] as? String ?? url.host ?? raw))
            }
            for item in object.values { sources += collect(item) }
            return sources
        }
        if let items = value as? [Any] { return items.flatMap { collect($0) } }
        return []
    }
}

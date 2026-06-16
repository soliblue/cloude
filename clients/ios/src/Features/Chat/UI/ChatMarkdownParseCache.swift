import Foundation

@MainActor
enum ChatMarkdownParseCache {
    private static var cache: [String: [ChatMarkdownBlock]] = [:]
    private static var order: [String] = []

    static func blocks(for text: String) -> [ChatMarkdownBlock] {
        if let cached = cache[text] { return cached }
        let blocks = ChatMarkdownParser.parse(text)
        if cache.count >= 24 { cache.removeValue(forKey: order.removeFirst()) }
        cache[text] = blocks
        order.append(text)
        return blocks
    }
}

import Foundation

@MainActor
enum ChatMarkdownParseCache {
    private static var cache: [String: [ChatMarkdownBlock]] = [:]

    static func blocks(for text: String) -> [ChatMarkdownBlock] {
        if let cached = cache[text] { return cached }
        let blocks = ChatMarkdownParser.parse(text)
        if cache.count >= 24 { cache.removeAll() }
        cache[text] = blocks
        return blocks
    }
}

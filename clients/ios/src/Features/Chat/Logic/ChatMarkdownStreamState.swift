import Foundation

struct ChatMarkdownStreamState {
    private(set) var frozen: [ChatMarkdownBlock] = []
    private(set) var tail: [ChatMarkdownBlock] = []
    private var tailStartLine = 0
    private var tailStartUTF8 = 0

    mutating func update(_ text: String, appendOnly: Bool) {
        if appendOnly,
            let parsed = ChatMarkdownParser.parseResuming(
                text, tailStartLine: tailStartLine, tailStartUTF8: tailStartUTF8)
        {
            if parsed.blocks.count > 1 { frozen.append(contentsOf: parsed.blocks.dropLast()) }
            tail = Array(parsed.blocks.suffix(1))
            tailStartLine = parsed.tailStartLine
            tailStartUTF8 = parsed.tailStartUTF8
        } else {
            let parsed = ChatMarkdownParser.parseWithTailStart(text)
            frozen = Array(parsed.blocks.dropLast())
            tail = Array(parsed.blocks.suffix(1))
            tailStartLine = parsed.tailStartLine
            tailStartUTF8 = parsed.tailStartUTF8
        }
    }
}

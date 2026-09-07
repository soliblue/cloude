import Foundation

func same(_ left: [ChatMarkdownBlock], _ right: [ChatMarkdownBlock]) -> Bool {
    left.count == right.count
        && zip(left, right).allSatisfy { lhs, rhs in
            switch (lhs, rhs) {
            case (.text(let a, let x, _), .text(let b, let y, _)): a == b && x == y
            case (.code(let a, let x, let langA, let doneA), .code(let b, let y, let langB, let doneB)):
                a == b && x == y && langA == langB && doneA == doneB
            case (.table(let a, let x), .table(let b, let y)): a == b && x == y
            case (.blockquote(let a, let x), .blockquote(let b, let y)): a == b && x == y
            case (.horizontalRule(let a), .horizontalRule(let b)): a == b
            case (.header(let a, let levelA, let x, _), .header(let b, let levelB, let y, _)):
                a == b && levelA == levelB && x == y
            default: false
            }
        }
}
let fixtures = [
    "# Heading\n\nHello **world** and `code` with 🇩🇪 é.\n\n## Next\n\nMore text.",
    "Start\n\n```swift\nlet answer = 42\n```\n\nEnd",
    "> First\n> Second\n\n- [x] Done\n- [ ] Next\n\nFinal",
    "| Name | Status |\n| --- | --- |\n| A | Done |\n\nEnd\n",
]
for fixture in fixtures {
    var state = ChatMarkdownStreamState()
    var text = ""
    for character in fixture {
        text.append(character)
        state.update(text, appendOnly: true)
        precondition(
            same(state.frozen + state.tail, ChatMarkdownParser.parse(text)),
            "Incremental mismatch for \(text)")
    }
    state.update("Replacement", appendOnly: false)
    precondition(same(state.frozen + state.tail, ChatMarkdownParser.parse("Replacement")))
}
let prefix = (0..<2000).map { "# Section \($0)\n\nParagraph \($0)\n\n" }.joined()
var oldFrozen = Array(ChatMarkdownParser.parse(prefix + "Tail").dropLast())
var oldTail: [ChatMarkdownBlock] = []
let initial = ChatMarkdownParser.parseWithTailStart(prefix + "Tail")
var tailLine = initial.tailStartLine
var tailUTF8 = initial.tailStartUTF8
let oldStart = Date()
for count in 1...500 {
    let parsed = ChatMarkdownParser.parseResuming(
        prefix + "Tail" + String(repeating: "x", count: count), tailStartLine: tailLine, tailStartUTF8: tailUTF8)!
    let blocks = oldFrozen + parsed.blocks
    oldFrozen = Array(blocks.dropLast())
    oldTail = Array(blocks.suffix(1))
    tailLine = parsed.tailStartLine
    tailUTF8 = parsed.tailStartUTF8
}
let oldTime = Date().timeIntervalSince(oldStart)
var state = ChatMarkdownStreamState()
state.update(prefix + "Tail", appendOnly: false)
let newStart = Date()
for count in 1...500 { state.update(prefix + "Tail" + String(repeating: "x", count: count), appendOnly: true) }
let newTime = Date().timeIntervalSince(newStart)
precondition(same(state.frozen + state.tail, oldFrozen + oldTail))
precondition(state.frozen.count == initial.blocks.count - 1)
print(
    "\(state.frozen.count) frozen markdown blocks + 500 tail updates: copy-all \(String(format: "%.2f", oldTime * 1000))ms; append-only \(String(format: "%.2f", newTime * 1000))ms"
)
print(
    "Passed incremental/full parser parity at every character: Unicode, formatting, code fences, lists, tables, replacement and complete history preservation"
)

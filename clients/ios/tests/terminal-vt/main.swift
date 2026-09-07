import Foundation
import SwiftTerm

let host = HeadlessTerminal(options: TerminalOptions(cols: 80, rows: 24, scrollback: 50)) { _ in }
let terminal = host.terminal!
let initial = Array("\u{1b}[2J\u{1b}[Hhello\u{1b}[31m world\u{1b}[0m\r\u{1b}[2Kdone 🙂e\u{301}".utf8)
for byte in initial { terminal.feed(buffer: [byte][...]) }
let screen = visibleText(terminal)
precondition(screen.contains("done 🙂e\u{301}") && !screen.contains("hello"))
terminal.feed(text: "\u{1b}[?1049h\u{1b}[Halternate")
precondition(visibleText(terminal).contains("alternate"))
terminal.feed(text: "\u{1b}[?1049l")
precondition(visibleText(terminal).contains("done 🙂e\u{301}"))
terminal.resize(cols: 60, rows: 12)
precondition(terminal.cols == 60 && terminal.rows == 12)
terminal.feed(text: "\u{1b}[?2004h")
precondition(terminal.bracketedPasteMode)
terminal.feed(text: "\u{1b}[?1h")
precondition(terminal.applicationCursor)
terminal.resetToInitialState()
for index in 0..<200 { terminal.feed(text: "line-\(index)\r\n") }
let rows = String(decoding: terminal.getBufferAsData(), as: UTF8.self).components(separatedBy: "\n")
precondition(rows.count <= 63 && rows.joined().contains("line-199") && !rows.joined().contains("line-0"))
print(
    "Passed real pinned SwiftTerm VT engine: single-byte fragmented ANSI/UTF8, erase/cursor, alternate screen restore, resize, bracketed paste, application cursor mode and bounded scrollback"
)

func visibleText(_ terminal: Terminal) -> String {
    (0..<terminal.rows).compactMap {
        terminal.getLine(row: $0)?.translateToString(
            trimRight: true, skipNullCellsFollowingWide: true,
            characterProvider: { terminal.getCharacter(for: $0) })
    }.joined(separator: "\n")
}

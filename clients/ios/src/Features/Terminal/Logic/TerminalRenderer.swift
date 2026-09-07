import Foundation
import SwiftTerm
import UIKit

@MainActor final class TerminalRenderer: NSObject, TerminalViewDelegate {
    let view: SwiftTerm.TerminalView
    var onInput: (Data) -> Void = { _ in }
    var onResize: (Int, Int) -> Void = { _, _ in }
    private var allowsResponses = true

    init(cols: Int, rows: Int) {
        view = SwiftTerm.TerminalView(
            frame: .zero,
            font: .monospacedSystemFont(ofSize: 14, weight: .regular),
            options: TerminalOptions(cols: cols, rows: rows, scrollback: 5000))
        super.init()
        view.terminalDelegate = self
        view.nativeBackgroundColor = .black
        view.nativeForegroundColor = .white
        view.caretColor = .white
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.autocorrectionType = .no
        view.autocapitalizationType = .none
    }

    var cols: Int { view.getTerminal().cols }
    var rows: Int { view.getTerminal().rows }

    func resize(cols: Int, rows: Int) {
        if cols > 0 && rows > 0 && (cols != self.cols || rows != self.rows) {
            view.getTerminal().resize(cols: cols, rows: rows)
            view.setNeedsDisplay()
        }
    }

    func fitToViewport() {
        let size = view.getOptimalFrameSize()
        if view.bounds.width > 0 && view.bounds.height > 0 && size.width > 0 && size.height > 0 {
            resize(
                cols: max(1, Int(view.bounds.width / (size.width / CGFloat(cols)))),
                rows: max(1, Int(view.bounds.height / (size.height / CGFloat(rows)))))
        }
    }

    func close() { view.updateUiClosed() }

    func feed(_ data: Data, allowResponses: Bool) {
        allowsResponses = allowResponses
        view.feed(byteArray: Array(data)[...])
        allowsResponses = true
    }

    func reset() {
        allowsResponses = false
        view.getTerminal().resetToInitialState()
        view.setNeedsDisplay()
        allowsResponses = true
    }

    func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
        if allowsResponses { onInput(Data(data)) }
    }

    func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) { onResize(newCols, newRows) }
    func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}
    func scrolled(source: SwiftTerm.TerminalView, position: Double) {}
    func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}
    func requestOpenLink(source: SwiftTerm.TerminalView, link: String, params: [String: String]) {
        if let url = URL(string: link), url.scheme == "https", url.user == nil, url.password == nil {
            UIApplication.shared.open(url)
        }
    }
}

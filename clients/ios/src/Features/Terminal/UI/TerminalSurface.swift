import SwiftTerm
import SwiftUI

struct TerminalSurface: UIViewRepresentable {
    let terminal: TerminalSessionStore

    func makeUIView(context: Context) -> SwiftTerm.TerminalView { terminal.renderer.view }

    func updateUIView(_ view: SwiftTerm.TerminalView, context: Context) {
        view.isUserInteractionEnabled = true
    }

    static func dismantleUIView(_ view: SwiftTerm.TerminalView, coordinator: ()) {
        _ = view.resignFirstResponder()
    }
}

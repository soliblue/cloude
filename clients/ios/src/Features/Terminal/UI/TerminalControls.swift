import SwiftTerm
import SwiftUI

struct TerminalControls: View {
    let terminal: TerminalSessionStore

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                Button("Keyboard", systemImage: "keyboard") { _ = terminal.renderer.view.becomeFirstResponder() }
                Button("Esc") { terminal.renderer.view.send([27]) }
                Button("Tab") { terminal.renderer.view.send([9]) }
                Button("Ctrl-C") { terminal.renderer.view.send([3]) }
                Button("Ctrl-D") { terminal.renderer.view.send([4]) }
                Button("Paste") { terminal.renderer.view.paste(nil) }
            }
            .font(.caption.monospaced())
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .disabled(!terminal.canInput)
        .scrollIndicators(.hidden)
    }
}

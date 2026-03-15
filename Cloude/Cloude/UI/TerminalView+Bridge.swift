import SwiftUI
import Combine
import SwiftTerm

class TerminalBridge: ObservableObject {
    var termView: SwiftTerm.TerminalView?

    var onSendBack: ((String) -> Void)?

    func feed(_ text: String) {
        DispatchQueue.main.async {
            self.termView?.feed(text: text)
        }
    }

}

class NoKeyboardTerminalView: SwiftTerm.TerminalView {}

struct SwiftTermWrapper: UIViewRepresentable {
    let bridge: TerminalBridge

    @Environment(\.appTheme) private var theme

    func makeUIView(context: Context) -> NoKeyboardTerminalView {
        let tv = NoKeyboardTerminalView(frame: .zero)
        tv.terminalDelegate = context.coordinator
        tv.nativeBackgroundColor = UIColor(Color.themeBackground)
        tv.nativeForegroundColor = theme.colorScheme == .light ? .black : .white
        tv.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        tv.isUserInteractionEnabled = true
        tv.isScrollEnabled = true
        tv.inputView = UIView(frame: .zero)
        tv.inputAccessoryView = nil
        bridge.termView = tv
        return tv
    }

    func updateUIView(_ uiView: NoKeyboardTerminalView, context: Context) {
        uiView.nativeBackgroundColor = UIColor(Color.themeBackground)
        uiView.nativeForegroundColor = theme.colorScheme == .light ? .black : .white
    }

    func makeCoordinator() -> Coordinator { Coordinator(bridge: bridge) }

    class Coordinator: NSObject, SwiftTerm.TerminalViewDelegate {
        let bridge: TerminalBridge

        init(bridge: TerminalBridge) {
            self.bridge = bridge
        }

        func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}

        func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
            let text = String(bytes: data, encoding: .utf8) ?? ""
            if !text.isEmpty {
                bridge.onSendBack?(text)
            }
        }

        func scrolled(source: SwiftTerm.TerminalView, position: Double) {}

        func requestOpenLink(source: SwiftTerm.TerminalView, link: String, params: [String : String]) {
            if let url = URL(string: link) {
                UIApplication.shared.open(url)
            }
        }

        func bell(source: SwiftTerm.TerminalView) {}

        func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {
            if let text = String(data: content, encoding: .utf8) {
                UIPasteboard.general.string = text
            }
        }

        func iTermContent(source: SwiftTerm.TerminalView, content: ArraySlice<UInt8>) {}
        func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}
    }
}

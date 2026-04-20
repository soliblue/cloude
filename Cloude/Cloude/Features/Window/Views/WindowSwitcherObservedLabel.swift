import SwiftUI

struct WindowSwitcherObservedLabel: View {
    let symbol: String
    let name: String
    let isActive: Bool
    let useSymbols: Bool
    @ObservedObject var output: ConversationOutput

    var body: some View {
        WindowSwitcherStaticLabel(
            symbol: symbol,
            name: name,
            isActive: isActive,
            useSymbols: useSymbols,
            isStreaming: output.phase != .idle
        )
    }
}

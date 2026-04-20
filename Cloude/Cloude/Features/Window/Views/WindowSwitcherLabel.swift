import SwiftUI

struct WindowSwitcherLabel: View {
    let symbol: String
    let name: String
    let isActive: Bool
    let useSymbols: Bool
    let output: ConversationOutput?

    var body: some View {
        if let output {
            WindowSwitcherObservedLabel(
                symbol: symbol,
                name: name,
                isActive: isActive,
                useSymbols: useSymbols,
                output: output
            )
        } else {
            WindowSwitcherStaticLabel(
                symbol: symbol,
                name: name,
                isActive: isActive,
                useSymbols: useSymbols,
                isStreaming: false
            )
        }
    }
}
